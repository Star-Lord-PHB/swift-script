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


// extension InstalledPackage {
    
//     static func load() async throws -> [InstalledPackage] {
//         try await JSONDecoder().decode(
//             [InstalledPackage].self,
//             from: .read(contentsOf: AppPath.installedPackagesUrl)
//         )
//     }
    
//     static func save(_ packages: [InstalledPackage]) async throws {
//         try await JSONEncoder().encode(packages).write(to: AppPath.installedPackagesUrl)
//     }
    
// }


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
        guard let lower = Version(string: lowerStr) else {
            throw ValidationError("invalid sematic version string: \(lowerStr)")
        }
        let next = switch option {
            case .upToNextMajor: Version(major: lower.major + 1, minor: 0, patch: 0)
            case .uptoNextMinor: Version(major: lower.major, minor: lower.minor + 1, patch: 0)
        }
        if let upperStr {
            guard let specifiedUpper = Version(string: upperStr) else {
                throw ValidationError("invalid sematic version string: \(lowerStr)")
            }
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


struct Version: Codable {
    let major: Int
    let minor: Int
    let patch: Int
}


extension Version {
    
    init?(string: String) {
        let components = string.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
        let intComponents = components.map { Int($0) } + [Int](repeating: 0, count: max(0, 3 - components.count))
        guard intComponents.allSatisfy({ $0 != nil }) else { return nil }
        guard let major = intComponents[0] else { return nil }
        guard let minor = intComponents[1] else { return nil }
        guard let patch = intComponents[2] else { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
}


extension Version: CustomStringConvertible {
    var description: String {
        "\(major).\(minor).\(patch)"
    }
}


extension Version: Comparable, Hashable {
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        guard lhs.major == rhs.major else { return lhs.major < rhs.major }
        guard lhs.minor == rhs.minor else { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
    
}
