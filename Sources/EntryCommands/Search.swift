//
//  Search.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptSearch: VerboseLoggableCommand {
    
    static let configuration: CommandConfiguration = .init(commandName: "search", shouldDisplay: false)

    @Argument(transform: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
    var identity: String 

    @OptionGroup
    var printInfoArguments: PrintInfoArguments

    @OptionGroup
    var listVersionsArguments: ListVersionsArguments

    @Flag(name: .long)
    var verbose: Bool = false

    var appEnv: AppEnv = .default


    func validate() throws {
        guard listVersionsArguments.limit > 0 else {
            throw ValidationError("limit must be greater than 0")
        }
    }
    

    func wrappedRun() async throws {

        let url = try await withLoadingIndicator("Searching ...") {
            guard let url = try await appEnv.searchPackage(of: identity) else {
                throw CLIError(reason: "Package \(identity) is not found in swift package index")
            }
            return url 
        }

        if listVersionsArguments.listVersions {
            try await printVersionList(url: url)
        } else {
            try await printInfo(url: url)
        }

    }


    private func printInfo(url: URL) async throws {

        let tag = try await printInfoArguments.version.unwrap(
            or: { 
                printLog("Version not specified, fetching latest version ...")
                return try await appEnv.fetchLatestVersionStr(of: url) 
            }
        )

        if printInfoArguments.version != nil {
            printLog("Checking if version \(tag) exists ...")
            guard try await appEnv.fetchRemoteTags(at: url).contains(tag) else {
                throw CLIError(reason: "Version \(tag) is not found in remote repository")
            }
        } else {
            print("Latest Version: \(tag)")
        }
        
        let packageFullDescription = try await withLoadingIndicator("Gathering Package Info ...") {
            try await appEnv.fetchPackageFullDescription(
                at: url, 
                tag: tag,
                includeDependencies: printInfoArguments.showDependencies, 
                verbose: verbose
            )
        }

        let platformStr = if packageFullDescription.platforms.isEmpty {
            "(Not Specified)"
        } else {
            packageFullDescription.platforms.map(\.description).joined(separator: ", ")
        }

        if printInfoArguments.showDependencies {
            printFromStart("""

                \("Identity".green): \(packageFullDescription.identity)
                \("Name".green): \(packageFullDescription.name)
                \("Url".green): \(packageFullDescription.url)
                \("Modules".green): \(packageFullDescription.modules.joined(separator: ", "))
                \("Platforms".green): \(platformStr)

                \("Dependencies".green):
                \(packageFullDescription.dependencyText)
                """
            )
        } else {
            printFromStart("""

                \("Identity".green): \(packageFullDescription.identity)
                \("Name".green): \(packageFullDescription.name)
                \("Url".green): \(packageFullDescription.url)
                \("Modules".green): \(packageFullDescription.modules.joined(separator: ", "))
                \("Platforms".green): \(platformStr)
                """
            )
        }

    }


    private func printVersionList(url: URL) async throws {
        let versions = try await withLoadingIndicator("Fetching Version List ...") {
            try await appEnv.fetchVersionList(of: url, verbose: verbose)
        }
        if listVersionsArguments.all {
            printFromStart(versions.map(\.str).joined(separator: "\n"))
        } else {
            printFromStart(
                versions.suffix(listVersionsArguments.limit)
                    .map(\.str)
                    .joined(separator: "\n")
            )
        }
    }


    struct PrintInfoArguments: ParsableArguments {

        @Flag(name: .long, help: "Whether to print out the dependency tree")
        var showDependencies: Bool = false

        @Option(
            name: .long, 
            help: .init(
                "Specify a version to search", 
                discussion: """
                    Available versions can be listed with --list-versions flag. 
                    Default to the latest version
                    """
            )
        )
        var version: String? = nil

    }


    struct ListVersionsArguments: ParsableArguments {

        @Flag(name: .long, help: "Whether to list available versions of the package")
        var listVersions: Bool = false

        @Option(name: .long, help: "Limit the max number of versions to list")
        var limit: Int = 10

        @Flag(name: .long, help: "List ALL available versions")
        var all: Bool = false

    }
    
}
