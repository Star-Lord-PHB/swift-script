//
//  InstalledPackage.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/9/24.
//

import Foundation
import ArgumentParser
import CodableMacro


@Codable
struct RunnerPackageDescription {
    
    @CodingField("tools_version")
    let toolsVersion: String
    var dependencies: [InstalledPackage]
    
}


struct InstalledPackage: Codable {
    
    var identity: String
    var url: URL
    var libraries: [String]
    var requirement: Requirement
    
    var dependencyCommand: String {
        switch requirement {
            case .exact(let exactVersion):
                #".package(url: "\#(url)", exact: "\#(exactVersion)")"#
            case .branch(let branch):
                #".package(url: "\#(url)", branch: "\#(branch)")"#
            case .range(let range):
                #".package(url: "\#(url)", "\#(range.lowerBound)" ..< "\#(range.upperBound)")"#
        }
    }
    
    @Codable
    struct Range: Equatable {
        @CodingField("lower_bound")
        let lowerBound: String
        @CodingField("upper_bound")
        let upperBound: String
    }
    
    enum Requirement: Codable, Equatable {
        
        case exact(String)
        case branch(String)
        case range(Range)
        
    }
    
    enum RequirementRangeOption {
        case upToNextMajor, uptoNextMinor
    }
    
}


extension InstalledPackage: CustomStringConvertible {
    var description: String {
        """
        \(identity):
            url: \(url)
            libraries: \(libraries)
            version requirement: \(requirement)
        """
    }
}


extension InstalledPackage.Requirement {
    
    static func range(
        from lowerStr: String,
        to upperStr: String? = nil,
        option: InstalledPackage.RequirementRangeOption = .upToNextMajor
    ) throws -> Self {
        let lower = try SemanticVersion.parse(lowerStr)
        let next = switch option {
            case .upToNextMajor: SemanticVersion(major: lower.major + 1, minor: 0, patch: 0)
            case .uptoNextMinor: SemanticVersion(major: lower.major, minor: lower.minor + 1, patch: 0)
        }
        if let upperStr {
            let specifiedUpper = try SemanticVersion.parse(upperStr)
            let upper = min(specifiedUpper, next)
            return .range(.init(lowerBound: lower.description, upperBound: upper.description))
        }
        return .range(.init(lowerBound: lower.description, upperBound: next.description))
    }
    
}


extension InstalledPackage.Requirement: CustomStringConvertible {
    var description: String {
        switch self {
            case .exact(let string):
                "exact \(string)"
            case .branch(let string):
                "branch \(string)"
            case .range(let range):
                "\(range.lowerBound) - \(range.upperBound)"
        }
    }
}
