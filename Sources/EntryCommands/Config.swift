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
        printFromStart(
            """
            swift tools version: \(config.swiftVersion)
            macOS min support version: \(config.macosVersion)
            """
        )
#else
        printFromStart(
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

    var appEnv: AppEnv = .default


#if os(macOS)
    func wrappedRun() async throws {

        guard swiftVersion != nil || macosVersion != nil else {
            warningLog("No config update specified")
            throw ExitCode.success
        }

        printLog("Loading current configuration")
        var config = try await appEnv.loadAppConfig()

        if let swiftVersion = swiftVersion {
            printLog("Changing swift tools version from \(config.swiftVersion) to \(swiftVersion)")
            config.swiftVersion = swiftVersion
        }
        if let macosVersion = macosVersion {
            printLog("Changing macOS min support version from \(config.macosVersion) to \(macosVersion)")
            config.macosVersion = macosVersion
        }

        printLog("Saving updated configuration")
        try await appEnv.saveAppConfig(config)

    }
#else
    func wrappedRun() async throws {
        
        guard swiftVersion != nil else {
            printFromStart("No config update specified")
            return 
        }

        var config = try await appEnv.loadAppConfig()

        if let swiftVersion = swiftVersion {
            printLog("Changing swift tools version from \(config.swiftVersion) to \(swiftVersion)")
            config.swiftVersion = swiftVersion
        }

        try await appEnv.saveAppConfig(config)

    }
#endif

}
