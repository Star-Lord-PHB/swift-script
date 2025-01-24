//
//  Info.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptInfo: SwiftScriptWrappedCommand {
    
    static let configuration: CommandConfiguration = .init(
        commandName: "info",
        abstract: "Show information about an installed package"
    )
    
    @Argument(
        help: "show detail information of a specified package",
        transform: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    )
    var package: String

    @Flag(name: .long, help: "Show dependencies of the package")
    var showDependencies: Bool = false
    
    @Flag(name: .long)
    var verbose: Bool = false

    var appEnv: AppEnv = .fromEnv()
    var logger: Logger = .init()
    

    func wrappedRun() async throws {
        
        let packageCheckoutPath = appEnv.packageCheckoutPath(of: package)
        
        try await appEnv.withProcessLock {
            
            guard await FileManager.default.fileExists(at: packageCheckoutPath) else {
                throw CLIError(reason: "Package \(package) is not installed")
            }
            
            logger.printDebug("Loading installation info of package \(package)")
            
            guard
                let packageInstallInfo = try await appEnv.loadInstalledPackages()
                    .first(where: { $0.identity == package })
            else { throw CLIError(reason: "Package \(package) is not installed") }
            
            logger.printDebug("Loading description of package \(package)")
            
            let packageDescription = try await appEnv.loadPackageDescription(
                of: packageCheckoutPath,
                as: PackageDescription.self
            )
            
            logger.printDebug("Loading resolved version of package \(package)")
            
            guard
                let resolvedVersion = try await appEnv.loadResolvedDependencyVersionList()
                    .first(where: { $0.identity == package })?
                    .version
            else { throw CLIError(reason: "Package \(package) is not installed") }

            let platformStr = if packageDescription.platforms.isEmpty {
                "(Not Specified)"
            } else {
                packageDescription.platforms.map(\.description).joined(separator: ", ")
            }

            if showDependencies {

                logger.printDebug("Loading dependencies of package \(package)")
                let dependenciesStr = try await appEnv.loadPackageDependenciesText(of: packageCheckoutPath)
                
                print("""
                    
                    \("Package identity:".green) \(package)
                    \("Package name:".green) \(packageDescription.name)
                    \("URL:".green) \(packageInstallInfo.url)
                    \("Specified Requirement:".green) \(packageInstallInfo.requirement)
                    \("Current Version:".green) \(resolvedVersion)
                    \("Platforms:".green) \(platformStr)
                    \("Modules:".green) \(packageDescription.modules.joined(separator: ", "))
                    
                    \("Dependencies:".green)
                    \(dependenciesStr)
                    """
                )

            } else {

                print("""
                    
                    \("Package identity:".green) \(package)
                    \("Package name:".green) \(packageDescription.name)
                    \("URL:".green) \(packageInstallInfo.url)
                    \("Specified Requirement:".green) \(packageInstallInfo.requirement)
                    \("Current Version:".green) \(resolvedVersion)
                    \("Platforms:".green) \(platformStr)
                    \("Modules:".green) \(packageDescription.modules.joined(separator: ", "))
                    """
                )

            }

        }
        
    }
    
}
