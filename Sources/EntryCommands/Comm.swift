//
//  Comm.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/11/2.
//

import ArgumentParser


struct PackageVersionSpecifierArguments: ParsableArguments {
    @Option(
        name: .customLong("exact"), 
        help: "exactly x.y.z", 
        transform: SemanticVersion.parse(_:)
    )
    var exactVersion: SemanticVersion?
    @Option(help: "name of the git branch")
    var branch: String?
    @Option(
        name: .customLong("from"), 
        help: "x.y.z to (x+1).0.0",
        transform: SemanticVersion.parse(_:)
    )
    var upToNextMajorVersion: SemanticVersion?
    @Option(
        name: .customLong("up-to-next-minor-from"), 
        help: "x.y.z to x.(y+1).0",
        transform: SemanticVersion.parse(_:)
    )
    var upToNextMinorVersion: SemanticVersion?
    @Option(
        name: .customLong("to"), 
        help: "maxinum version allowed",
        transform: SemanticVersion.parse(_:)
    )
    var upperBoundVersion: SemanticVersion?
}


extension PackageVersionSpecifierArguments {

    func selfValidate() -> Bool {
        let versionSpecifiers = [exactVersion, branch, upToNextMajorVersion, upToNextMinorVersion] as [Any?]
        return versionSpecifiers.count(where: { $0 != nil }) <= 1
    }

}
