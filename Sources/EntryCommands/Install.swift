//
//  Install.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptInstall: SwiftScriptWrappedCommand {
    
    static let configuration: CommandConfiguration = .init(commandName: "install")
    
    @Argument(
        help: "The package to install (identity or url of the package)", 
        transform: { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    )
    var package: String
    
    @OptionGroup
    var packageVersionSpecifier: PackageVersionSpecifierArguments
    
    @Flag(name: .shortAndLong)
    var verbose: Bool = false
    
    @Flag(name: .shortAndLong, help: "If set, then when the specified package is already installed, it will be replaced without prompt")
    var forceReplace: Bool = false
    
    @Option(name: .customLong("Xbuild"), parsing: .singleValue, help: #"Pass flag through to "swift build" command"#)
    var buildArguments: [String] = []

    @Flag(help: "If set, will not build the package after installation (NOT RECOMMENDED! Aimed only for faster testing)")
    var noBuild: Bool = false

    var appEnv: AppEnv = .default
    var logger: Logger = .init()
    
    var exactVersion: SemanticVersion? { packageVersionSpecifier.exactVersion }
    var branch: String? { packageVersionSpecifier.branch }
    var upToNextMajorVersion: SemanticVersion? { packageVersionSpecifier.upToNextMajorVersion }
    var upToNextMinorVersion: SemanticVersion? { packageVersionSpecifier.upToNextMinorVersion }
    var upperBoundVersion: SemanticVersion? { packageVersionSpecifier.upperBoundVersion }
    
    
    func validate() throws {
        guard packageVersionSpecifier.selfValidate() else {
            throw CLIError(
                reason: "expect at most ONE option within `--exact`, `--from`, `--up-to-next-minor-from` and `--branch`"
            )
        }
    }
    
    
    func wrappedRun() async throws {

        let (newPackageIdentity, packageRemoteUrl) = try await resolveIdentityAndUrl()
        
        try await appEnv.withProcessLock {

            logger.printDebug("Loading installed packages and package manifest")
            let original = try await appEnv.cacheOriginals(\.installedPackages, \.packageManifest)
        
            var installedPackages = original.installedPackages!
            
            logger.printDebug("Checking whether package is already installed")
            if let conflictPackageIndex = installedPackages
                .firstIndex(where: { $0.identity == newPackageIdentity }) {

                if !forceReplace {

                    let conflictPackage = installedPackages[conflictPackageIndex]
                    print("Package \(conflictPackage.identity) is already installed (\(conflictPackage.requirement))")
                    print("Would you like to overwrite it? [y/n] (default: n):", terminator: " ")
                    
                    let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard input == "y" || input == "yes" else {
                        print("Aborted")
                        throw ExitCode.success
                    }

                }

                print("Removing package \(newPackageIdentity)")
                installedPackages.remove(at: conflictPackageIndex)
                
            }
            
            logger.printDebug("Calculating version requirement")
            let requirement = try await extractRequirement(packageRemoteUrl)
            
            print("Version requirement extracted as: \(requirement)")
            
            logger.printDebug("Fetching products of package \(newPackageIdentity)")
            let newPackageProducts = try await appEnv.fetchPackageProducts(
                of: packageRemoteUrl,
                requirement: requirement
            )
            
            print("Found products: \(newPackageProducts.libraries.map(\.name).joined(separator: ", "))")
            
            installedPackages.append(
                .init(
                    identity: newPackageIdentity,
                    url: packageRemoteUrl,
                    libraries: newPackageProducts.libraries.map(\.name),
                    requirement: requirement
                )
            )
            
            registerCleanUp { 
                logger.printDebug("Restoring original package manifest and installed packages")
                try? await appEnv.restoreOriginals(original)
            }
            
            print("Saving updated installed packages")
            try await appEnv.saveInstalledPackages(installedPackages)
            print("Saving updating runner package manifest")
            try await appEnv.updatePackageManifest(installedPackages: installedPackages)
            
            if noBuild {
                print("Resolving (will not build since `--no-build` is set)")
                try await appEnv.resolveRunnerPackage(verbose: verbose)
            } else {
                print("Building ...")
                try await appEnv.buildRunnerPackage(arguments: buildArguments, verbose: true)
            }
            
        }
        
    }


    private func resolveIdentityAndUrl() async throws -> (String, URL) {

        let packageRemoteUrl: URL 
        let newPackageIdentity: String
        
        if let url = URL(string: package), url.scheme != nil {
            logger.printDebug("Input identified as package URL")
            packageRemoteUrl = url
            newPackageIdentity = packageIdentity(of: packageRemoteUrl)
            logger.printDebug("Package identity identified as \(newPackageIdentity)")
        } else {
            logger.printDebug("Input identified as package identity")
            logger.printDebug("Searching package \(package) in swift package index")
            newPackageIdentity = package
            if let url = try await appEnv.searchPackage(of: package) {
                packageRemoteUrl = url
            } else {
                throw CLIError(reason: "Package \(package) is not found in swift package index")
            }
            print("Found package \(package) with remote url: \(packageRemoteUrl)")
        }

        return (newPackageIdentity, packageRemoteUrl)

    }
    
    
    private func extractRequirement(_ remoteUrl: URL) async throws -> InstalledPackage.Requirement {
        
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
                    from: await appEnv.fetchLatestVersion(of: remoteUrl, upTo: .init(string: upperBoundVersion.description)).description,
                    to: upperBoundVersion.description,
                    option: .upToNextMajor
                )
            } else {
                try .range(
                    from: await appEnv.fetchLatestVersion(of: remoteUrl).description,
                    to: upperBoundVersion?.description,
                    option: .upToNextMajor
                )
            }
        }
        
    }
    
}