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

    
    func wrappedRun() async throws {
        
        try await appEnv.withProcessLock {

            printLog("Loading installed packages")
            let installedPackages = try await appEnv.loadInstalledPackages()
            let identitiesToRemove = Set(identities)
            
            printLog("Caching current runner package manifest")
            let originalPackageManifest = try await appEnv.loadPackageManifes()

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
            
            printLog("Loading configuration")
            let config = try await appEnv.loadAppConfig()
            
            printFromStart("Removing \(identities.joined(separator: ", "))")
            
            registerCleanUp {
                printFromStart("Restoring original package manifest and installed packages")
                try? await originalPackageManifest.write(to: appEnv.runnerPackageManifestUrl)
                try? await appEnv.saveInstalledPackages(installedPackages)
            }
            
            printFromStart("Saving updated installed packages")
            try await appEnv.saveInstalledPackages(updatedPackages)
            printFromStart("Saving updated runner package manifest")
            try await appEnv.updatePackageManifest(installedPackages: updatedPackages, config: config)
            
            if noBuild {
                printFromStart("Resolving (will not build since `--no-build` is set)")
                try await appEnv.resolveRunnerPackage(verbose: verbose)
            } else {
                printFromStart("Building")
                try await appEnv.buildRunnerPackage(arguments: buildArguments, verbose: true)
            }
            
        }
        
    }
    
}
