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
    
    @Argument(help: "The package to install", transform: URL.parse(_:))
    var package: URL
    
    @OptionGroup
    var packageVersionSpecifier: PackageVersionSpecifierArguments
    
    @Flag(name: .shortAndLong)
    var verbose: Bool = false
    
    @Flag(help: "If set, then when the specified package is already installed, it will be replaced without prompt")
    var forceReplace: Bool = false
    
    @Option(name: .customLong("Xbuild"), parsing: .singleValue, help: #"Pass flag through to "swift build" command"#)
    var buildArguments: [String] = []

    @Flag(help: "If set, will not build the package after installation (NOT RECOMMENDED! Aimed only for faster testing)")
    var noBuild: Bool = false

    var appEnv: AppEnv = .default
    
    var exactVersion: Version? { packageVersionSpecifier.exactVersion }
    var branch: String? { packageVersionSpecifier.branch }
    var upToNextMajorVersion: Version? { packageVersionSpecifier.upToNextMajorVersion }
    var upToNextMinorVersion: Version? { packageVersionSpecifier.upToNextMinorVersion }
    var upperBoundVersion: Version? { packageVersionSpecifier.upperBoundVersion }
    
    
    func validate() throws {
        guard packageVersionSpecifier.selfValidate() else {
            throw CLIError(
                reason: "expect at most ONE option within `--exact`, `--from`, `--up-to-next-minor-from` and `--branch`"
            )
        }
    }
    
    
    func wrappedRun() async throws {
        
        try await appEnv.withProcessLock {

            let newPackageIdentity = packageIdentity(of: package)
            
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
                requirement: requirement
            )
            
            printLog("Found products: \(newPackageProducts.libraries.map(\.name).joined(separator: ", "))")
            
            installedPackages.append(
                .init(
                    identity: newPackageIdentity,
                    url: package,
                    libraries: newPackageProducts.libraries.map(to: \.name),
                    requirement: requirement
                )
            )
            
            registerCleanUp { 
                print("Restoring original package manifest and installed packages")
                try? await originalPackageManifest.write(to: appEnv.runnerPackageManifestUrl)
                try? await appEnv.saveInstalledPackages(originalPackages)
            }
            
            print("Saving updated installed packages")
            try await appEnv.saveInstalledPackages(installedPackages)
            print("Saving updating runner package manifest")
            try await appEnv.updatePackageManifest(installedPackages: installedPackages, config: config)
            
            if noBuild {
                print("Resolving (will not build since `--no-build` is set)")
                try await appEnv.resolveRunnerPackage(verbose: verbose)
            } else {
                print("Building")
                try await appEnv.buildRunnerPackage(arguments: buildArguments, verbose: true)
            }
            
        }
        
    }
    
    
    private func extractRequirement() async throws -> InstalledPackage.Requirement {
        
        return if let exactVersion {
            .exact(exactVersion.description)
        } else if let branch {
            .branch(branch)
        } else if let upToNextMajorVersion {
            try .range(from: upToNextMajorVersion.description, to: upperBoundVersion?.description, option: .upToNextMajor)
        } else if let upToNextMinorVersion {
            try .range(from: upToNextMinorVersion.description, to: upperBoundVersion?.description, option: .uptoNextMinor)
        } else {
            if let upperBoundVersion {
                try .range(
                    from: await appEnv.fetchLatestVersion(of: package, upTo: .init(string: upperBoundVersion.description)).description,
                    to: upperBoundVersion.description,
                    option: .upToNextMajor
                )
            } else {
                try .range(
                    from: await appEnv.fetchLatestVersion(of: package).description,
                    to: upperBoundVersion?.description,
                    option: .upToNextMajor
                )
            }
        }
        
    }
    
}