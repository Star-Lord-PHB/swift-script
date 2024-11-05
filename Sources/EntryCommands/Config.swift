import Foundation
import ArgumentParser


struct SwiftScriptConfig: VerboseLoggableCommand {

    static let configuration: CommandConfiguration = .init(
        commandName: "config",
        subcommands: [SwiftScriptConfigSet.self]
    )

    func wrappedRun() async throws {
        let config = try await AppConfig.load()
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

    @Option
    var swiftVersion: String?

#if os(macOS)
    @Option
    var macosVersion: String?
#endif
    
    @Flag(name: .long)
    var verbose: Bool = false

#if os(macOS)
    func wrappedRun() async throws {

        guard swiftVersion != nil || macosVersion != nil else {
            warningLog("No config update specified")
            throw ExitCode.success
        }

        printLog("Loading current configuration")
        var config = try await AppConfig.load()

        if let swiftVersion = swiftVersion {
            guard let version = Version(string: swiftVersion) else {
                try errorAbort("\(swiftVersion) is not a valid swift version")
            }
            printLog("Changing swift tools version from \(config.swiftVersion) to \(version)")
            config.swiftVersion = version
        }
        if let macosVersion = macosVersion {
            guard let version = Version(string: macosVersion) else {
                try errorAbort("\(macosVersion) is not a vlid macOS version string")
            }
            printLog("Changing macOS min support version from \(config.macosVersion) to \(version)")
            config.macosVersion = version
        }

        printLog("Saving updated configuration")
        try await config.save()

    }
#else
    func wrappedRun() async throws {
        
        guard swiftVersion != nil else {
            print("No config update specified")
            return 
        }

        var config = try await AppConfig.load()

        if let swiftVersion = swiftVersion {
            guard let version = Version(string: swiftVersion) else {
                try errorAbort("\(swiftVersion) is not a valid swift version")
            }
            printLog("Changing swift tools version from \(config.swiftVersion) to \(version)")
            config.swiftVersion = version
        }

        try await config.save()

    }
#endif

}
