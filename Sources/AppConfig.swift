//
//  AppConfig.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/2.
//

import Foundation
import FileManagerPlus
import CodableMacro


struct AppConfig: Equatable {
    
    var macosVersion: Version
    var swiftVersion: Version
    
}


extension AppConfig {
    
    private struct AppConfigCodingStructure: Codable {
        var swiftVersion: String?
        var macosVersion: String?
    }
    
    
    static func load() async throws -> AppConfig {
        let structure = try await JSONDecoder().decode(
            AppConfigCodingStructure.self,
            from: .read(contentsOf: AppPath.configFileUrl)
        )
        var systemVersion: Version {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return Version(major: version.majorVersion, minor: version.minorVersion, patch: version.patchVersion)
        }
        let macosVersion = if let str = structure.macosVersion {
            Version(string: str) ?? systemVersion
        } else {
            systemVersion
        }
        let swiftVersion = if let str = structure.swiftVersion {
            try await Version(string: str).unwrap(or: { try await CMD.fetchSwiftVersion() })
        } else {
            try await CMD.fetchSwiftVersion()
        }
        return .init(
            macosVersion: macosVersion,
            swiftVersion: swiftVersion
        )
    }
    
    
    func save() async throws {
        let structure = AppConfigCodingStructure(
            swiftVersion: swiftVersion.description,
            macosVersion: macosVersion.description
        )
        try await JSONEncoder().encode(structure).write(to: AppPath.configFileUrl)
    }
    
}
