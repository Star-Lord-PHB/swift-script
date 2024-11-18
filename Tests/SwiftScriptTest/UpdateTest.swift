import Foundation
import FileManagerPlus
import Testing
@testable import SwiftScript


@Suite("Test Update")
class UpdateTest: SwiftScriptTestBase {

    let originalInstalledIdentities: Set<String> = 
        TestPackage.allCasesWithNoRequirement.map(\.identity).toSet()

    override init() async throws {
        try await super.init()
        try await setupAppFolderWithTemplate(.preInstalled)
        let installedPackageIdentities = try await validateAndLoadInstalledPackages()
            .map(\.identity)
            .toSet()
        try #require(installedPackageIdentities == originalInstalledIdentities)
    }


    @Test(
        "Update with Install Command",
        arguments: [
            .swiftSystem(.upToNextMajor("1.2.0")),
            .swiftSystem(.upToNextMinor("1.2.0")),
            .swiftSystem(.notSpecified),
            .swiftSystem(.upTo("1.3.2")),
            .swiftArgumentParser(.exact("1.3.1")),
            .swiftArgumentParser(.branch("main")),
        ] as [TestPackage]
    )
    func test1(spec: TestPackage) async throws {

        var installCommand = try SwiftScriptInstall.parse([spec.url.absoluteString] + spec.requirement.cmdArgs)
        installCommand.noBuild = true
        installCommand.appEnv = appEnv
        installCommand.forceReplace = true

        // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
        try await installCommand.wrappedRun()

        let installedPackages = try await validateAndLoadInstalledPackages()

        let packageInfo = try #require(installedPackages.first(where: { $0.identity == spec.identity }))

        validateRequirement(packageInfo.requirement, spec.requirement)

    }


    @Test(
        "Update with Update Command",
        arguments: [
            .swiftSystem(.upToNextMajor("1.2.0")),
            .swiftSystem(.upToNextMinor("1.2.0")),
            .swiftSystem(.notSpecified),
            .swiftSystem(.upTo("1.3.2")),
            .swiftArgumentParser(.exact("1.3.1")),
            .swiftArgumentParser(.branch("main")),
        ] as [TestPackage]
    )
    func test2(spec: TestPackage) async throws {

        var updateCommand = try SwiftScriptUpdate.parse([spec.identity] + spec.requirement.cmdArgs)
        updateCommand.noBuild = true
        updateCommand.appEnv = appEnv

        // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
        try await updateCommand.wrappedRun()

        let installedPackages = try await validateAndLoadInstalledPackages()

        #expect(installedPackages.contains(where: { $0.identity == spec.identity }))

        let packageInfo = installedPackages.first(where: { $0.identity == spec.identity })!

        validateRequirement(packageInfo.requirement, spec.requirement)

    }


    @Test(
        "Invalid Update Command",
        arguments: [
            (
                "swift-system", 
                ["--from", "1.4.0", "--up-to-next-minor", "1.4.0"],
                "only one requirement specifier should be used"
            ),
            (
                "swift-system",
                ["--branch", "main", "--exact", "1.4.0"],
                "only one requirement specifier should be used"
            ),
            (
                "swift-system",
                ["--from", "1.invalid.0"],
                "Bad version number"
            ),
        ] as [(String, [String], String)]
    )
    func test3(identity: String, requirement: [String], reason: String) async throws {

        #expect(throws: Error.self, "\(reason)") {
            try SwiftScriptUpdate.parse([identity] + requirement)
        }

    }


    @Test(
        "Bad Identity / Version / Requirement",
        arguments: [
            (
                "swift-system",
                .upToNextMajor(.init(string: "1000.0.0")!, upper: nil),
                "Version not exist"
            ),
            (
                "not-exist",
                .branch("main"),
                "Package not installed"
            ),
            (
                "swift-system",
                .branch("not-exist"),
                "Branch not exist"
            ),
        ] as [(String, Requirement, String)]
    )
    func test4(identity: String, requirement: Requirement, reason: String) async throws {
        
        var updateCommand = try SwiftScriptUpdate.parse([identity] + requirement.cmdArgs)
        updateCommand.noBuild = true
        updateCommand.appEnv = appEnv

        await #expect(throws: Error.self, "\(reason)") {
            // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
            try await updateCommand.wrappedRun()
        }

    }

}