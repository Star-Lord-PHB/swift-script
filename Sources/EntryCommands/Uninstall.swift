//
//  Uninstall.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptUninstall: VerboseLoggableCommand {
    
    static let configuration: CommandConfiguration = .init(
        commandName: "uninstall",
        aliases: ["remove", "rm"]
    )
    
    @Argument(transform: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
    var identities: [String]
    
    @Option(name: .customLong("Xbuild"), parsing: .singleValue, help: #"Pass flag through to "swift build" command"#)
    var buildArguments: [String] = []

    @Flag(help: "If set, will not build the package after installation (NOT RECOMMENDED! Aimed only for faster testing)")
    var noBuild: Bool = false

    var appEnv: AppEnv = .default
    var logger: Logger = .init()

    
    func wrappedRun() async throws {
        
        try await appEnv.withProcessLock {

            let identitiesToRemove = identities.toSet()

            logger.printDebug("Loading package manifest and installed packages")
            let original = try await appEnv.cacheOriginals(\.packageManifest, \.installedPackages)

            let installedPackages = original.installedPackages!

            let updatedPackages = installedPackages.filter { 
                !identitiesToRemove.contains($0.identity) 
            }

            guard installedPackages.count - updatedPackages.count == identitiesToRemove.count else {
                let notInstalledPackages = identitiesToRemove
                    .subtracting(installedPackages.map(\.identity).toSet())
                throw CLIError(reason: """
                    The following packages are not installed:
                    \(notInstalledPackages.joined(separator: "\n"))
                    """
                )
            }
            
            logger.printDebug("Loading configuration")
            let config = try await appEnv.loadAppConfig()
            
            print("Removing \(identities.joined(separator: ", "))")
            
            registerCleanUp {
                logger.printDebug("Restoring original package manifest and installed packages")
                try? await appEnv.restoreOriginals(original)
            }
            
            print("Saving updated installed packages")
            try await appEnv.saveInstalledPackages(updatedPackages)
            print("Saving updated runner package manifest")
            try await appEnv.updatePackageManifest(installedPackages: updatedPackages, config: config)
            
            if noBuild {
                print("Resolving (will not build since `--no-build` is set)")
                try await appEnv.resolveRunnerPackage(verbose: verbose)
            } else {
                print("Building")
                try await appEnv.buildRunnerPackage(arguments: buildArguments, verbose: true)
            }
            
        }
        
    }
    
}
