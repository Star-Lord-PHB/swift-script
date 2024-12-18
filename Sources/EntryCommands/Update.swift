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
    
    @Argument(transform: { $0.trimmingCharacters(in: .whitespaces).lowercased() })
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

    @Flag(help: "If set, will not build the package after installation (NOT RECOMMENDED! Aimed only for faster testing)")
    var noBuild: Bool = false

    var appEnv: AppEnv = .default
    
    
    func validate() throws {
        if package != nil && all {
            throw CleanExit.helpRequest(self)
        }
        guard packageUpdateVersionSpec.selfValidate() else {
            throw CLIError( 
                reason: "expect at most ONE option within `--exact`, `--from`, `--up-to-next-minor-from` and `--branch`"
            )
        }
    }
    
    
    func wrappedRun() async throws {
        
        if let package {
            
            printLog("Loading installed packages")
            guard
                let url = try await appEnv.loadInstalledPackages()
                    .first(where: { $0.identity == package })?.url
            else { throw CLIError(reason: "Package \(package) is not installed") }
            
            var installCommand = SwiftScriptInstall(appEnv: appEnv)
            installCommand.package = url.absoluteString
            installCommand.packageVersionSpecifier = packageUpdateVersionSpec
            installCommand.buildArguments = buildArguments
            installCommand.verbose = verbose
            installCommand.forceReplace = true
            installCommand.noBuild = noBuild
            
            try await installCommand.wrappedRun()
            
        } else if all {
            
            try await appEnv.withProcessLock {

                printLog("Loading configuration")
                let config = try await appEnv.loadAppConfig()
            
                printLog("Caching current installed packages")
                let originalPackages = try await appEnv.loadInstalledPackages()
                printLog("Caching current runner package manifest")
                let originalPackageManifest = try await appEnv.loadPackageManifes()
                
                let updatedPackages = try await updatePackages(originalPackages, config: config)
                
                let modifiedPackages = zip(originalPackages, updatedPackages).filter {
                    $0.requirement != $1.requirement
                }
                
                guard modifiedPackages.isNotEmpty else {
                    printFromStart("No updatable packages found")
                    throw ExitCode.success
                }
                
                printFromStart("""
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
                        printFromStart("Aborted")
                        throw ExitCode.success
                    }
                }
                
                registerCleanUp {
                    try? await originalPackageManifest.write(to: appEnv.runnerPackageManifestUrl)
                    try? await appEnv.saveInstalledPackages(originalPackages)
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
                        from: appEnv.fetchLatestVersion(of: package.url).description,
                        option: .upToNextMajor
                    )
                } as InstalledPackage.Requirement
                
                guard newRequirement != package.requirement else {
                    return package
                }
                
                let products = try await appEnv.fetchPackageProducts(
                    of: package.url,
                    requirement: package.requirement
                )
                
                var package = package
                package.requirement = newRequirement
                package.libraries = products.libraries.map(\.name)
                
                return package
                
            }.collectAsArray()
        
    }

    
}
