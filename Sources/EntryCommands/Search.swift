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

    @Flag(name: .long)
    var verbose: Bool = false

    @Flag(name: .long)
    var showDependencies: Bool = false

    var appEnv: AppEnv = .default
    

    func wrappedRun() async throws {

        let url = try await withLoadingIndicator("Searching ...") {
            guard let url = try await appEnv.searchPackage(of: identity) else {
                throw CLIError(reason: "Package \(identity) is not found in swift package index")
            }
            return url 
        }

        let packageFullDescription = try await withLoadingIndicator("Gathering Package Info ...") {
            try await appEnv.fetchPackageFullDescription(
                at: url, 
                includeDependencies: showDependencies, 
                verbose: verbose
            )
        }

        let platformStr = if packageFullDescription.platforms.isEmpty {
            "(Not Specified)"
        } else {
            packageFullDescription.platforms.map(\.description).joined(separator: ", ")
        }

        if showDependencies {
            print("""

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
            print("""

                \("Identity".green): \(packageFullDescription.identity)
                \("Name".green): \(packageFullDescription.name)
                \("Url".green): \(packageFullDescription.url)
                \("Modules".green): \(packageFullDescription.modules.joined(separator: ", "))
                \("Platforms".green): \(platformStr)
                """
            )
        }

    }
    
}
