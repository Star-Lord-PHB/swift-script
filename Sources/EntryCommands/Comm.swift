//
//  Comm.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/11/2.
//

import ArgumentParser


struct PackageVersionSpecifierArguments: ParsableArguments {
    @Option(name: .customLong("exact"))
    var exactVersion: String?
    @Option
    var branch: String?
    @Option(name: .customLong("from"))
    var upToNextMajorVersion: String?
    @Option(name: .customLong("up-to-next-minor-from"))
    var upToNextMinorVersion: String?
    @Option(name: .customLong("to"))
    var upperBoundVersion: String?
}
    
