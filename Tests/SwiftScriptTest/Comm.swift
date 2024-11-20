import Foundation
@testable import SwiftScript


enum Requirement {
    case upToNextMinor(SemanticVersion, upper: SemanticVersion?)
    case upToNextMajor(SemanticVersion, upper: SemanticVersion?)
    case exact(SemanticVersion)
    case branch(String)
    case notSpecified
    case upTo(SemanticVersion)
}


extension Requirement {

    static func upToNextMajor(_ version: String, upper: String? = nil) -> Self {
        if let upper {
            .upToNextMajor(.init(string: version)!, upper: .init(string: upper)!)
        } else {
            .upToNextMajor(.init(string: version)!, upper: nil)
        }
    }

    static func upToNextMinor(_ version: String, upper: String? = nil) -> Self {
        if let upper {
            .upToNextMinor(.init(string: version)!, upper: .init(string: upper)!)
        } else {
            .upToNextMinor(.init(string: version)!, upper: nil)
        }
    }

    static func exact(_ version: String) -> Self {
        .exact(.init(string: version)!)
    }

    static func upTo(_ version: String) -> Self {
        .upTo(.init(string: version)!)
    }

    var cmdArgs: [String] {
        switch self {
            case .upToNextMinor(let version, let .some(upper)):
                return ["--up-to-next-minor-from", version.description, "--to", upper.description]
            case .upToNextMinor(let version, nil):
                return ["--up-to-next-minor-from", version.description]
            case .upToNextMajor(let version, let .some(upper)):
                return ["--from", version.description, "--to", upper.description]
            case .upToNextMajor(let version, nil):
                return ["--from", version.description]
            case .exact(let version):
                return ["--exact", version.description]
            case .branch(let branch):
                return ["--branch", branch]
            case .upTo(let version):
                return ["--to", version.description]
            case .notSpecified: 
                return []
        }
    }

}


enum Template: String {
    case preInstalled = "pre-installed"
    case empty = "empty"
}


enum TestPackage {
    case swiftSystem(Requirement)
    case swiftAsyncAlgorithms(Requirement)
    case swiftLog(Requirement)
    case swiftNumerics(Requirement)
    case swiftArgumentParser(Requirement)
    case swiftCollections(Requirement)
    var requirement: Requirement {
        switch self {
            case .swiftSystem(let requirement),
                .swiftAsyncAlgorithms(let requirement),
                .swiftLog(let requirement),
                .swiftNumerics(let requirement),
                .swiftArgumentParser(let requirement),
                .swiftCollections(let requirement):
                return requirement
        }
    }
    var url: URL {
        switch self {
            case .swiftSystem: .init(string: "https://github.com/apple/swift-system.git")!
            case .swiftAsyncAlgorithms: .init(string: "https://github.com/apple/swift-async-algorithms.git")!
            case .swiftLog: .init(string: "https://github.com/apple/swift-log.git")!
            case .swiftNumerics: .init(string: "https://github.com/apple/swift-numerics.git")!
            case .swiftArgumentParser: .init(string: "https://github.com/apple/swift-argument-parser.git")!
            case .swiftCollections: .init(string: "https://github.com/apple/swift-collections.git")!
        }
    }
    var urlStr: String { url.absoluteString }
    var identity: String { packageIdentity(from: url) }
    static var allCasesWithNoRequirement: [TestPackage] {
        [
            .swiftSystem(.notSpecified),
            .swiftAsyncAlgorithms(.notSpecified),
            .swiftLog(.notSpecified),
            .swiftNumerics(.notSpecified),
            .swiftArgumentParser(.notSpecified),
            .swiftCollections(.notSpecified),
        ]
    }
}


enum TestPackageIdentity: String, CaseIterable {
    case swiftSystem
    case swiftAsyncAlgorithms
    case swiftLog
    case swiftNumerics
    case swiftArgumentParser
    case swiftCollections
    var rawValue: String {
        switch self {
            case .swiftSystem: TestPackage.swiftSystem(.notSpecified).identity
            case .swiftAsyncAlgorithms: TestPackage.swiftAsyncAlgorithms(.notSpecified).identity
            case .swiftLog: TestPackage.swiftLog(.notSpecified).identity
            case .swiftNumerics: TestPackage.swiftNumerics(.notSpecified).identity
            case .swiftArgumentParser: TestPackage.swiftArgumentParser(.notSpecified).identity
            case .swiftCollections: TestPackage.swiftCollections(.notSpecified).identity
        }
    }
}


func packageIdentity(from url: URL) -> String {
    if url.pathExtension == "git" {
        return url.deletingPathExtension().lastPathComponent
    } else {
        return url.lastPathComponent
    }
}