//
//  Update.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptUpdate: VerboseLoggableCommand {
    
    static let configuration: CommandConfiguration = .init(commandName: "update")
    
    @Argument
    var package: String?
    
    @OptionGroup
    var packageUpdateVersionSpec: PackageVersionSpecifierArguments
    
    @Flag
    var all: Bool = false
    
    @Option(name: .customLong("Xbuild"), parsing: .singleValue, help: #"Pass flag through to "swift build" command"#)
    var buildArguments: [String] = []
    
    @Flag(name: .shortAndLong)
    var verbose: Bool = false
    
    @Flag(name: [.customShort("y"), .customLong("yes")])
    var noPrompt: Bool = false
    
    
    func validate() throws {
        if package != nil && all {
            throw CleanExit.helpRequest(self)
        }
    }
    
    
    func wrappedRun() async throws {
        
        if let package = package?.trimmingCharacters(in: .whitespaces) {
            
            printLog("Loading installed packages")
            guard
                let url = try await InstalledPackage.load()
                    .first(where: { $0.identity == package })?.url
            else { try errorAbort("Package \(package) is not installed") }
            
            var installCommand = SwiftScriptInstall()
            installCommand.package = url.absoluteString
            installCommand.packageVersionSpecifier = packageUpdateVersionSpec
            installCommand.buildArguments = buildArguments
            installCommand.verbose = verbose
            installCommand.forceReplace = true
            
            try await installCommand.run()
            
        } else if all {
            
            try await ProcessLock.shared.withLock {

                printLog("Loading configuration")
                let config = try await AppConfig.load()
            
                printLog("Caching current installed packages")
                let originalPackages = try await InstalledPackage.load()
                printLog("Caching current runner package manifest")
                let originalPackageManifest = try await loadPackageManifes()
                
                let updatedPackages = try await updatePackages(originalPackages, config: config)
                
                let modifiedPackages = zip(originalPackages, updatedPackages).filter {
                    $0.requirement != $1.requirement
                }
                
                guard modifiedPackages.isNotEmpty else {
                    print("No updatable packages found")
                    throw ExitCode.success
                }
                
                print("""
                    Package requirements will be updated as follow:
                    \(
                        modifiedPackages
                            .map { "\($0.identity): (\($0.requirement.description.red)) -> (\($1.requirement.description.green))" }
                            .joined(separator: "\n")
                    )
                    """
                )
                
                if !noPrompt {
                    print("Proceed? (y/n): ", terminator: "")
                    let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard input == "y" || input == "yes" else {
                        print("Aborted")
                        throw ExitCode.success
                    }
                }
                
                registerCleanUp {
                    try? await originalPackageManifest.write(to: AppPath.runnerPackageManifestUrl)
                    try? await JSONEncoder().encode(originalPackages).write(to: AppPath.runnerPackageManifestUrl)
                }
                
                print("Saving updated installed packages")
                try await InstalledPackage.save(updatedPackages)
                print("Saving updated runner package manifest")
                try await updatePackageManifest(installedPackages: updatedPackages, config: config)
                
                print("Building")
                try await CMD.buildRunnerPackage(arguments: buildArguments, verbose: true)
                
            }
            
        } else {
            throw CleanExit.helpRequest(self)
        }
        
    }
    
    
    private func updatePackages(
        _ originalPackages: [InstalledPackage],
        config: AppConfig
    ) async throws -> [InstalledPackage] {
        
        try await originalPackages.enumerated().async
            .map { i, package in
                
                printOverlapping("[\(i + 1)/\(originalPackages.count)] Checking \(package.identity)")
                if i == originalPackages.count - 1 { print() }
                
                let newRequirement = switch package.requirement {
                    case .branch, .exact: package.requirement
                    case .range: try await .range(
                        from: CMD.fetchLatestVersion(of: package.url).description,
                        option: .upToNextMajor
                    )
                } as InstalledPackage.Requirement
                
                guard newRequirement != package.requirement else {
                    return package
                }
                
                let products = try await CMD.fetchPackageProducts(
                    of: package.url,
                    requirement: package.requirement,
                    config: config
                )
                
                var package = package
                package.requirement = newRequirement
                package.libraries = products.libraries.map(\.name)
                
                return package
                
            }.collectAsArray()
        
    }

    
}
