//
//  Comm.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/11/2.
//

import ArgumentParser


struct PackageVersionSpecifierArguments: ParsableArguments {
    @Option(name: .customLong("exact"), transform: Version.parse(_:))
    var exactVersion: Version?
    @Option
    var branch: String?
    @Option(name: .customLong("from"), transform: Version.parse(_:))
    var upToNextMajorVersion: Version?
    @Option(name: .customLong("up-to-next-minor-from"), transform: Version.parse(_:))
    var upToNextMinorVersion: Version?
    @Option(name: .customLong("to"), transform: Version.parse(_:))
    var upperBoundVersion: Version?
}


extension PackageVersionSpecifierArguments {

    func selfValidate() -> Bool {
        let versionSpecifiers = [exactVersion, branch, upToNextMajorVersion, upToNextMinorVersion] as [Any?]
        return versionSpecifiers.count(where: { $0 != nil }) <= 1
    }

}
