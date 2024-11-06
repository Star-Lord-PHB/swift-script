//
//  Install.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptInstall: VerboseLoggableCommand {
    
    static let configuration: CommandConfiguration = .init(commandName: "install")
    
    @Argument(help: "The package to install")
    var package: String
    
    @OptionGroup
    var packageVersionSpecifier: PackageVersionSpecifierArguments
    
    @Flag(name: .shortAndLong)
    var verbose: Bool = false
    
    @Flag(help: "If set, then when the specified package is already installed, it will be replaced without prompt")
    var forceReplace: Bool = false
    
    @Option(name: .customLong("Xbuild"), parsing: .singleValue, help: #"Pass flag through to "swift build" command"#)
    var buildArguments: [String] = []

    var appEnv: AppEnv = .default
    
    var exactVersion: String? { packageVersionSpecifier.exactVersion }
    var branch: String? { packageVersionSpecifier.branch }
    var upToNextMajorVersion: String? { packageVersionSpecifier.upToNextMajorVersion }
    var upToNextMinorVersion: String? { packageVersionSpecifier.upToNextMinorVersion }
    var upperBoundVersion: String? { packageVersionSpecifier.upperBoundVersion }
    
    
    func validate() throws {
        guard [exactVersion, branch, upToNextMajorVersion, upToNextMinorVersion].count(where: { $0 != nil }) <= 1 else {
            try errorAbort(
                "expect at most ONE option within `--exact`, `--from`, `--up-to-next-minor-from` and `--branch`"
            )
        }
    }
    
    
    func wrappedRun() async throws {
        
        try await appEnv.withProcessLock {

            let newPackageIdentity = try appEnv.packageIdentity(of: package)
            
            printLog("Package identity identified as \(newPackageIdentity)")
        
            printLog("Loading installed packages")
            var installedPackages = try await appEnv.loadInstalledPackages()
            printLog("Loading configuration")
            let config = try await appEnv.loadAppConfig()
            
            let originalPackages = installedPackages
            printLog("Caching current runner package manifest")
            let originalPackageManifest = try await appEnv.loadPackageManifes()
            
            printLog("Checking whether package is already installed")
            conflictHandle: if let conflictPackageIndex = installedPackages
                .firstIndex(where: { $0.identity == newPackageIdentity }) {
                
                defer {
                    print("Removing package \(newPackageIdentity)")
                    installedPackages.remove(at: conflictPackageIndex)
                }
                
                guard !forceReplace else { break conflictHandle }
                
                let conflictPackage = installedPackages[conflictPackageIndex]
                print("Package \(conflictPackage.identity) is already installed (\(conflictPackage.requirement))")
                print("Would you like to overwrite it? [y/n] (default: n):", terminator: " ")
                
                let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard input == "y" || input == "yes" else {
                    print("Aborted")
                    throw ExitCode.success
                }
                
            }
            
            printLog("Calculating version requirement")
            let requirement = try await extractRequirement()
            
            print("Version requirement extracted as: \(requirement)")
            
            print("Fetching products of package \(newPackageIdentity)")
            let newPackageProducts = try await appEnv.fetchPackageProducts(
                of: package,
                requirement: requirement,
                config: config
            )
            
            printLog("Found products: \(newPackageProducts.libraries.map(\.name).joined(separator: ", "))")
            
            installedPackages.append(
                .init(
                    identity: newPackageIdentity,
                    url: .init(string: package)!,
                    libraries: newPackageProducts.libraries.map(to: \.name),
                    requirement: requirement
                )
            )
            
            registerCleanUp {
                print("Restoring original package manifest and installed packages")
                try? await originalPackageManifest.write(to: appEnv.runnerPackageManifestUrl)
                try? await JSONEncoder().encode(originalPackages).write(to: appEnv.installedPackagesUrl)
            }
            
            print("Saving updated installed packages")
            try await appEnv.saveInstalledPackages(installedPackages)
            print("Saving updating runner package manifest")
            try await appEnv.updatePackageManifest(installedPackages: installedPackages, config: config)
            
            print("Building")
            try await appEnv.buildRunnerPackage(arguments: buildArguments, verbose: true)
            
        }
        
    }
    
    
    private func extractRequirement() async throws -> InstalledPackage.Requirement {
        
        return if let exactVersion {
            .exact(exactVersion)
        } else if let branch {
            .branch(branch)
        } else if let upToNextMajorVersion {
            try .range(from: upToNextMajorVersion, to: upperBoundVersion, option: .upToNextMajor)
        } else if let upToNextMinorVersion {
            try .range(from: upToNextMinorVersion, to: upperBoundVersion, option: .uptoNextMinor)
        } else {
            try .range(
                from: await appEnv.fetchLatestVersion(of: package, upTo: upperBoundVersion).description,
                to: upperBoundVersion,
                option: .upToNextMajor
            )
        }
        
    }
    
}
