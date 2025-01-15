import Foundation
import ArgumentParser


struct SwiftScriptConfig: VerboseLoggableCommand {

    static let configuration: CommandConfiguration = .init(
        commandName: "config",
        subcommands: [SwiftScriptConfigSet.self]
    )

    var appEnv: AppEnv = .default


    func wrappedRun() async throws {
        let config = try await appEnv.loadAppConfig()
#if os(macOS)
        print(
            """
            swift tools version: \(config.swiftVersion)
            macOS min support version: \(config.macosVersion)
            """
        )
#else
        print(
            """
            swift tools version: \(config.swiftVersionStr)
            """
        )
#endif
    }

}


struct SwiftScriptConfigSet: VerboseLoggableCommand {

    static let configuration: CommandConfiguration = .init(commandName: "set")

    @Option(transform: Version.parse(_:))
    var swiftVersion: Version?

#if os(macOS)
    @Option(transform: Version.parse(_:))
    var macosVersion: Version?
#endif
    
    @Flag(name: .long)
    var verbose: Bool = false

    @Flag(help: "If set, will not build the package after installation (NOT RECOMMENDED! Aimed only for faster testing)")
    var noBuild: Bool = false

    var appEnv: AppEnv = .default
    var logger: Logger = .init()


    func wrappedRun() async throws {

        guard swiftVersion != nil || macosVersion != nil else {
            logger.printWarning("No config update specified")
            throw ExitCode.success
        }

        logger.printDebug("Loading original configuration and package manifest ...")
        let original = try await appEnv.cacheOriginals(\.config, \.packageManifest)

        logger.printDebug("Loading installed packages ...")
        let installedPackages = try await appEnv.loadInstalledPackages()

        var config = original.config!

        if let swiftVersion = swiftVersion {
            logger.printDebug("Changing swift tools version from \(config.swiftVersion) to \(swiftVersion)")
            config.swiftVersion = swiftVersion
        }
#if os(macOS)
        if let macosVersion = macosVersion {
            logger.printDebug("Changing macOS min support version from \(config.macosVersion) to \(macosVersion)")
            config.macosVersion = macosVersion
        }
#endif // os(macOS)

        registerCleanUp(when: .interrupt) { 
            logger.printDebug("restoring original configuration and package manifest ...")
            try? await appEnv.restoreOriginals(original)
        }

        logger.printDebug("Saving updated configuration")
        try await appEnv.saveAppConfig(config)

        logger.printDebug("Updating runner package manifest")
        try await appEnv.updatePackageManifest(installedPackages: installedPackages, config: config)

        if !noBuild {
            print("Full Re-Building...")
            try await appEnv.cleanRunnerPackage()
            try await appEnv.buildRunnerPackage(verbose: true)
        } 

    }

}
