//
//  InstallTest.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/11/4.
//

import Testing
import Foundation
@testable import SwiftScript


@Suite("Test Install")
class InstallTest: SwiftScriptTestBase {

    override init() async throws {
        try await super.init()
        try await setupAppFolderWithTemplate(.empty)
    }

    
    @Test(
        "Standard Install with url",
        arguments: [
            .swiftSystem(.upToNextMajor("1.4.0")),
            .swiftSystem(.upToNextMinor("1.3.0")),
            .swiftSystem(.notSpecified),
            .swiftSystem(.upTo("1.3.0")),
            .swiftArgumentParser(.exact("1.3.1")),
            .swiftArgumentParser(.branch("main")),
        ] as [TestPackage]
    )
    func test1(spec: TestPackage) async throws {

        var installCommand = try SwiftScriptInstall.parse([spec.url.absoluteString] + spec.requirement.cmdArgs)
        installCommand.noBuild = true
        installCommand.appEnv = appEnv

        // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
        try await installCommand.wrappedRun()

        let installedPackages = try await validateAndLoadInstalledPackages()

        let packageInfo = try #require(
            installedPackages.first(where: { $0.identity == spec.identity })
        )

        validateRequirement(packageInfo.requirement, spec.requirement)

    }


    @Test(
        "Standard Install with identity",
        arguments: [
            .swiftSystem(.upToNextMajor("1.4.0")),
            .swiftSystem(.upToNextMinor("1.3.0")),
            .swiftSystem(.notSpecified),
            .swiftSystem(.upTo("1.3.0")),
            .swiftArgumentParser(.exact("1.3.1")),
            .swiftArgumentParser(.branch("main")),
        ] as [TestPackage]
    )
    func test2(spec: TestPackage) async throws {

        var installCommand = try SwiftScriptInstall.parse([spec.identity] + spec.requirement.cmdArgs)
        installCommand.noBuild = true
        installCommand.appEnv = appEnv

        // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
        try await installCommand.wrappedRun()

        let installedPackages = try await validateAndLoadInstalledPackages()

        let packageInfo = try #require(
            installedPackages.first(where: { $0.identity == spec.identity })
        )

        validateRequirement(packageInfo.requirement, spec.requirement)

    }


    @Test(
        "Invalid Install Command",
        arguments: [
            (
                "https://github.com/apple/swift-system.git", 
                ["--from", "1.4.0", "--up-to-next-minor", "1.4.0"],
                "only one requirement specifier should be used"
            ),
            (
                "https://github.com/apple/swift-system.git",
                ["--branch", "main", "--exact", "1.4.0"],
                "only one requirement specifier should be used"
            ),
            (
                "https://github.com/apple/swift-system.git",
                ["--from", "1.invalid.0"],
                "Bad version number"
            ),
        ] as [(String, [String], String)]
    )
    func test3(url: String, requirement: [String], reason: String) async throws {
        
        #expect(throws: Error.self, "\(reason)") {
            try SwiftScriptInstall.parse([url] + requirement)
        }

    }


    @Test(
        "Bad URL / Identity / Version / Requirement",
        arguments: [
            (
                "https://github.com/apple/swift-system.git",
                .upToNextMajor(.init(string: "1000.0.0")!, upper: nil),
                "Version not exist"
            ),
            (
                "https://github.com/serika/not-exist.git",
                .branch("main"),
                "URL not exist"
            ),
            (
                "identity-not-exist",
                .branch("main"),
                "Identity not exist"
            ),
            (
                "https://github.com/apple/swift-system.git",
                .branch("not-exist"),
                "Branch not exist"
            ),
        ] as [(String, Requirement, String)]
    )
    func test4(url: String, requirement: Requirement, reason: String) async throws {
        
        var installCommand = try SwiftScriptInstall.parse([url] + requirement.cmdArgs)
        installCommand.noBuild = true
        installCommand.appEnv = appEnv

        await #expect(throws: Error.self) {
            // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
            try await installCommand.wrappedRun()
        }

    }
    
}