//
//  ResolvedDependencyVersion.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/24.
//

import Foundation
import CodableMacro
import SwiftCommand


@Codable
struct ResolvedDependencyVersionList {
    @CodingField("pins")
    let dependencies: [ResolvedDependencyVersion]
}


@Codable
struct ResolvedDependencyVersion {
    
    let identity: String
    
    @CodingField("state", "version")
    let semanticVersion: String?
    
    @CodingField("state", "revision")
    let commitHash: String?
    
    var version: Version {
        return if let semanticVersion {
            .semantic(semanticVersion)
        } else if let commitHash {
            .commit(commitHash)
        } else {
            .unknown
        }
    }
    
    enum Version: CustomStringConvertible {
        case semantic(String), commit(String), unknown
        var description: String {
            switch self {
                case .semantic(let string), .commit(let string): string
                case .unknown: "unknown"
            }
        }
    }
    
}



extension ResolvedDependencyVersionList {
    
    static func load() async throws -> Self {
        
        try await CMD.resolveRunnerPackage()
        
        return try await JSONDecoder().decode(
            self,
            from: .read(contentsOf: AppPath.runnerResolvedPackagesUrl)
        )
        
    }
    
}
