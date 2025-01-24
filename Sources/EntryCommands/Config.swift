import Foundation
import ArgumentParser
import SystemPackage


struct SwiftScriptConfig: SwiftScriptWrappedCommand {

    static let configuration: CommandConfiguration = .init(
        commandName: "config",
        abstract: "Show the current SwiftScript configuration.",
        subcommands: [SwiftScriptConfigSet.self]
    )

    var appEnv: AppEnv = .fromEnv()


    func wrappedRun() async throws {
        let config = appEnv.appConfig
#if os(macOS)
        print(
            """
            swift path: \(config.swiftFilePath ?? "(not specified)")
            swift tools version: \(config.swiftVersion?.description ?? "(not specified)")
            macOS min support version: \(config.macosVersion?.description ?? "(not specified)")
            editor: 
                path: \(config.editorConfig?.editorPath ?? "(not specified)")
                arguments: \(config.editorConfig?.editorArguments.joined(separator: " ") ?? "(not specified)")
            """
        )
#else
        print(
            """
            swift path: \(config.swiftFilePath ?? "(not specified)")
            swift tools version: \(config.swiftVersion?.description ?? "(not specified)")
            editor: 
                path: \(config.editorConfig?.editorPath ?? "(not specified)")
                arguments: \(config.editorConfig?.editorArguments.joined(separator: " ") ?? "(not specified)")
            """
        )
#endif
    }

}



struct SwiftScriptConfigSet: SwiftScriptWrappedCommand {

    static let configuration: CommandConfiguration = .init(
        commandName: "set", 
        abstract: "Modify the SwiftScript configuration.",
        subcommands: [SwiftScriptSetEditor.self]
    )

    @Option(
        help: "The swift tools version for building and running the script, default to the compiler's version", 
        transform: Version.parse(_:)
    )
    var swiftVersion: Version?

    @Option(
        help: "The path to the swift binary, default to use the environment", 
        transform: FilePath.init(_:)
    )
    var swiftPath: FilePath?

    @Flag(help: "Clear the swift path from the config")
    var clearSwiftPath: Bool = false

    @Flag(help: "Clear the swift tools version from the config")
    var clearSwiftVersion: Bool = false

#if os(macOS)
    @Option(help: "The macOS min support version", transform: Version.parse(_:))
    var macosVersion: Version?

    @Flag(help: "Clear the macOS min support version from the config")
    var clearMacosVersion: Bool = false
#endif
    
    @Flag(name: .long)
    var verbose: Bool = false

    @Flag(help: "If set, will not build the package after installation (NOT RECOMMENDED! Aimed only for faster testing)")
    var noBuild: Bool = false

    var appEnv: AppEnv = .fromEnv()
    var logger: Logger = .init()


    func wrappedRun() async throws {

        guard hasInput else {
            logger.printWarning("No config update specified")
            throw ExitCode.success
        }

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


    private var hasInput: Bool {
#if os(macOS)
        swiftVersion != nil || macosVersion != nil || swiftPath != nil || clearSwiftPath || clearSwiftVersion || clearMacosVersion
#else
        swiftVersion != nil || swiftPath != nil || clearSwiftPath || clearSwiftVersion
#endif
    }

}



struct SwiftScriptSetEditor: SwiftScriptWrappedCommand {

    static let configuration: CommandConfiguration = .init(
        commandName: "editor",
        abstract: "Set the editor for editing scripts.",
        discussion: """
            MUST make sure that the binary will not return before the editor window is closed, \
            otherwise SwiftScript will delete the editing workspace immediately.
            For example, if VSCode is used, make sure to use the `-n` and `--wait` arguments.
            By default, it try to find VSCode the the PATH and run it with `code -n --wait`.
            """
    )

    @Argument(
        help: "The path to the preferred editor binary", 
        transform: FilePath.init(_:)
    )
    var editorPath: FilePath?

    @Argument(parsing: .captureForPassthrough, help: "The arguments to pass to the editor")
    var editorArguments: [String] = []

    @Flag(help: "Clear the editor configuration")
    var clear: Bool = false

    @Flag(name: .long)
    var verbose: Bool = false

    var appEnv: AppEnv = .fromEnv()
    var logger: Logger = .init()


    func wrappedRun() async throws {

        let editorConfig: EditorConfig?
        if clear {
            logger.printDebug("Clearing editor configuration")
            editorConfig = nil 
        } else if let editorPath {
            logger.printDebug("Setting editor configuration to \(editorPath.string) \(editorArguments.joined(separator: " "))")
            editorConfig = .init(editorPath: editorPath.string, editorArguments: editorArguments)
        } else {
            logger.printWarning("No editor configuration specified")
            throw ExitCode.success
        }

        var config = appEnv.appConfig
        config.editorConfig = editorConfig

        try await appEnv.saveAppConfig(config)

    }

}