//
//  Info.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand

let green: String = "\u{001B}[0;32m"
let reset: String = "\u{001B}[0;0m"


struct SwiftScriptInfo: VerboseLoggableCommand {
    
    static let configuration: CommandConfiguration = .init(commandName: "info")
    
    @Argument(
        help: "show detail information of a specified package",
        transform: {  $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    )
    var package: String
    
    @Flag(name: .long)
    var verbose: Bool = false

    var appEnv: AppEnv = .default
    

    func wrappedRun() async throws {
        
        let packageCheckoutPath = appEnv.packageCheckoutUrl(of: package)
        
        try await appEnv.withProcessLock {
            
            guard await FileManager.default.fileExistsAsync(at: packageCheckoutPath) else {
                throw CLIError(reason: "Package \(package) is not installed")
            }
            
            printLog("Loading metadata of package \(package)")
            
            guard
                let packageDescription = try await appEnv.loadInstalledPackages()
                    .first(where: { $0.identity == package })
            else { throw CLIError(reason: "Package \(package) is not installed") }
            
            printLog("Loading dependencies of package \(package)")
            
            let dependenciesStr = try await appEnv.loadPackageDependenciesText(of: packageCheckoutPath)
            
            printLog("Loading modules of package \(package)")
            
            let packageModules = try await appEnv.loadPackageDescription(
                of: packageCheckoutPath,
                as: PackageModules.self
            )
            
            printLog("Loading resolved version of package \(package)")
            
            guard
                let resolvedVersion = try await appEnv.loadResolvedDependencyVersionList()
                    .first(where: { $0.identity == package })?
                    .version
            else { throw CLIError(reason: "Package \(package) is not installed") }
            
            let infoStr = """
                
                \("Package identity:".green) \(package)
                \("Package name:".green) \(packageModules.name)
                \("URL:".green) \(packageDescription.url)
                \("Specified Requirement:".green) \(packageDescription.requirement)
                \("Current Version:".green) \(resolvedVersion)
                \("Modules:".green) \(packageModules.modules.joined(separator: ", "))
                
                \("Dependencies:".green)
                \(dependenciesStr)
                """
            
            print(infoStr)

        }
        
    }
    
}
