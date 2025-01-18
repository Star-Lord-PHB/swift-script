import Foundation
import ArgumentParser
import SystemPackage


struct SwiftScriptConfig: SwiftScriptWrappedCommand {

    static let configuration: CommandConfiguration = .init(
        commandName: "config",
        subcommands: [SwiftScriptConfigSet.self]
    )

    var appEnv: AppEnv = .default


    func wrappedRun() async throws {
        let config = appEnv.appConfig
#if os(macOS)
        print(
            """
            swift path: \(config.swiftFilePath ?? "(not specified)")
            swift tools version: \(config.swiftVersion?.description ?? "(not specified)")
            macOS min support version: \(config.macosVersion?.description ?? "(not specified)")
            """
        )
#else
        print(
            """
            swift path: \(config.swiftFilePath ?? "(not specified)")
            swift tools version: \(config.swiftVersion?.description ?? "(not specified)")
            """
        )
#endif
    }

}



struct SwiftScriptConfigSet: SwiftScriptWrappedCommand {

    static let configuration: CommandConfiguration = .init(commandName: "set")

    @Option(transform: Version.parse(_:))
    var swiftVersion: Version?

    @Option(transform: FilePath.init(_:))
    var swiftPath: FilePath?

    @Flag 
    var clearSwiftPath: Bool = false

    @Flag
    var clearSwiftVersion: Bool = false

#if os(macOS)
    @Flag
    var clearMacosVersion: Bool = false

    @Option(transform: Version.parse(_:))
    var macosVersion: Version?
#endif
    
    @Flag(name: .long)
    var verbose: Bool = false

    @Flag(help: "If set, will not build the package after installation (NOT RECOMMENDED! Aimed only for faster testing)")
    var noBuild: Bool = false

    var appEnv: AppEnv = .default
    var logger: Logger = .init()


    func validate() throws {
        
#if os(macOS)
        guard swiftVersion != nil || macosVersion != nil || swiftPath != nil || clearSwiftPath || clearSwiftVersion || clearMacosVersion else {
            logger.printWarning("No config update specified")
            throw ExitCode.success
        }
#else
        guard swiftVersion != nil || swiftPath != nil || clearSwiftPath || clearSwiftVersion else {
            logger.printWarning("No config update specified")
            throw ExitCode.success
        }
#endif

    }


    func wrappedRun() async throws {

        logger.printDebug("Loading original configuration and package manifest ...")
        let original = try await appEnv.cacheOriginals(\.config, \.packageManifest)

        logger.printDebug("Loading installed packages ...")
        let installedPackages = try await appEnv.loadInstalledPackages()

        var config = appEnv.appConfig

        if let swiftVersion {
            logger.printDebug("Changing swift tools version from \(config.swiftVersion?.description ?? "(not specified)") to \(swiftVersion)")
            config.swiftVersion = swiftVersion
        } else if clearSwiftVersion {
            logger.printDebug("Clearing swift tools version")
            config.swiftVersion = nil
        }
        if let swiftPath {
            let pathStr = swiftPath.components.isEmpty ? nil : swiftPath.string
            logger.printDebug("Changing swift path from \(config.swiftPath ?? "(not specified)") to \(pathStr ?? "(not specified)")")
            config.swiftPath = pathStr
        } else if clearSwiftPath {
            logger.printDebug("Clearing swift path")
            config.swiftPath = nil
        }
#if os(macOS)
        if let macosVersion {
            logger.printDebug("Changing macOS min support version from \(config.macosVersion?.description ?? "(not specified)") to \(macosVersion)")
            config.macosVersion = macosVersion
        } else if clearMacosVersion {
            logger.printDebug("Clearing macOS min support version")
            config.macosVersion = nil
        }
#endif // os(macOS)

        registerCleanUp(when: .interrupt) { 
            logger.printDebug("restoring original configuration and package manifest ...")
            try? await appEnv.restoreOriginals(original)
        }

        logger.printDebug("Saving updated configuration")
        try await appEnv.saveAppConfig(config)

        logger.printDebug("Updating runner package manifest")
        try await appEnv.updatePackageManifest(installedPackages: installedPackages)

        if !noBuild {
            print("Full Re-Building...")
            try await appEnv.cleanRunnerPackage()
            try await appEnv.buildRunnerPackage(verbose: true)
        } 

    }

}
