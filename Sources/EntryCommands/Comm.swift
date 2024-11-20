//
//  Comm.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/11/2.
//

import ArgumentParser


struct PackageVersionSpecifierArguments: ParsableArguments {
    @Option(name: .customLong("exact"), transform: SemanticVersion.parse(_:))
    var exactVersion: SemanticVersion?
    @Option
    var branch: String?
    @Option(name: .customLong("from"), transform: SemanticVersion.parse(_:))
    var upToNextMajorVersion: SemanticVersion?
    @Option(name: .customLong("up-to-next-minor-from"), transform: SemanticVersion.parse(_:))
    var upToNextMinorVersion: SemanticVersion?
    @Option(name: .customLong("to"), transform: SemanticVersion.parse(_:))
    var upperBoundVersion: SemanticVersion?
}


extension PackageVersionSpecifierArguments {

    func selfValidate() -> Bool {
        let versionSpecifiers = [exactVersion, branch, upToNextMajorVersion, upToNextMinorVersion] as [Any?]
        return versionSpecifiers.count(where: { $0 != nil }) <= 1
    }

}
