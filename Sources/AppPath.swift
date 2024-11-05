//
//  AppPath.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/9/24.
//

import Foundation
import FileManagerPlus
import SwiftParser
import SwiftSyntax
import Synchronization


enum AppPath {
    
    static let appBaseUrl: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingCompat(path: ".swift-script")
    
    static let tempUrl: URL = appBaseUrl.appendingCompat(path: "temp")
    
    static func makeTempFolder() async throws -> URL {
        let url = tempUrl.appendingCompat(path: UUID().uuidString)
        try await FileManager.default.createDirectory(at: url)
        return url
    }
    
    static func withTempFolder<R>(operation: (URL) async throws -> R) async throws -> R {
        let url = try await makeTempFolder()
        do {
            let result = try await operation(url)
            try await FileManager.default.remove(at: url)
            return result
        } catch {
            try await FileManager.default.remove(at: url)
            throw error
        }
    }
    
    static let runnerPackageUrl: URL = appBaseUrl.appendingCompat(path: "runner")
    
    static let runnerPackageManifestUrl: URL = runnerPackageUrl.appendingCompat(path: "Package.swift")
    
    static let runnerResolvedPackagesUrl: URL = runnerPackageUrl.appendingCompat(path: "Package.resolved")
    
    static let installedPackageCheckoutsUrl: URL = runnerPackageUrl.appendingCompat(path: ".build/checkouts")
    
    static let installedPackagesUrl: URL = appBaseUrl.appendingCompat(path: "packages.json")
    
    static let configFileUrl: URL = appBaseUrl.appendingCompat(path: "config.json")
    
    static func scriptBuildUrl(ofType type: ScriptType) -> URL {
        let name = switch type {
            case .mainEntry: "Runner.swift"
            case .topLevel: "main.swift"
        }
        return runnerPackageUrl
            .appendingCompat(path: "Sources")
            .appendingCompat(path: name)
    }
    
    static let execUrl: URL = appBaseUrl.appendingCompat(path: "exec")
    
    static func makeExecTempUrl() -> URL {
        execUrl.appendingCompat(path: UUID().uuidString)
    }
    
    static let executableProductUrl: URL = runnerPackageUrl.appendingCompat(path: ".build/release/Runner")
    
}


enum ScriptType {
    case topLevel, mainEntry
}


extension ScriptType: CustomStringConvertible {
    var description: String {
        switch self {
            case .topLevel: return "Top Level"
            case .mainEntry: return "Custom Main Entry"
        }
    }
}



extension ScriptType {
    
    static func of(fileAt url: URL) async throws -> ScriptType {
        
        guard let scriptContent = try await String(data: .read(contentsOf: url), encoding: .utf8) else {
            fatalError("Fail to read contents of the script")
        }
        
        let syntax = Parser.parse(source: scriptContent)
        
        let hasEntry = syntax.statements.lazy
            .compactMap { codeBlockItem in
                codeBlockItem.item.as(StructDeclSyntax.self)
            }
            .contains { structDecl in
                structDecl.attributes.lazy
                    .compactMap { attribute in
                        attribute
                            .as(AttributeSyntax.self)?
                            .attributeName
                            .as(IdentifierTypeSyntax.self)?
                            .name.trimmed.text
                    }
                    .contains(where: { $0 == "main" })
            }
        
        return hasEntry ? .mainEntry : .topLevel
        
    }
    
}
