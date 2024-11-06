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
    
    @Argument
    var identities: [String]
    
    @Option(name: .customLong("Xbuild"), parsing: .singleValue, help: #"Pass flag through to "swift build" command"#)
    var buildArguments: [String] = []

    var appEnv: AppEnv = .default

    
    func wrappedRun() async throws {
        
        try await appEnv.withProcessLock {

            printLog("Loading installed packages")
            var installedPackages = try await appEnv.loadInstalledPackages()
            var identitiesToRemove = Set(identities.map { $0.lowercased() })
            
            let originalPackages = installedPackages
            printLog("Caching current runner package manifest")
            let originalPackageManifest = try await appEnv.loadPackageManifes()
            
            for (i, package) in installedPackages.enumerated()
            where identitiesToRemove.contains(package.identity) {
                identitiesToRemove.remove(package.identity)
                installedPackages.remove(at: i)
            }
            
            guard identitiesToRemove.count == 0 else {
                try errorAbort("""
                    The following packages are not installed:
                    \(identitiesToRemove.joined(separator: "\n"))
                    """
                )
            }
            
            printLog("Loading configuration")
            let config = try await appEnv.loadAppConfig()
            
            print("Removing \(identities.joined(separator: ", "))")
            
            registerCleanUp {
                print("Restoring original package manifest and installed packages")
                try? await originalPackageManifest.write(to: appEnv.runnerPackageManifestUrl)
                try? await appEnv.saveInstalledPackages(originalPackages)
            }
            
            print("Saving updated installed packages")
            try await appEnv.saveInstalledPackages(installedPackages)
            print("Saving updated runner package manifest")
            try await appEnv.updatePackageManifest(installedPackages: installedPackages, config: config)
            
            print("Building")
            try await appEnv.buildRunnerPackage(arguments: buildArguments, verbose: true)
            
        }
        
    }
    
}
