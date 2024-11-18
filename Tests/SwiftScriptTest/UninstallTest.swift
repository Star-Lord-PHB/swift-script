import Foundation
import Testing
@testable import SwiftScript


@Suite("Test Uninstall")
class UninstallTest: SwiftScriptTestBase {

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
        "Normal Uninstall",
        arguments: [
            [.swiftSystem],
            [.swiftCollections, .swiftSystem],
            [.swiftAsyncAlgorithms, .swiftArgumentParser, .swiftCollections],
            [.swiftArgumentParser],
            [.swiftLog, .swiftSystem],
            [
                .swiftSystem,
                .swiftCollections,
                .swiftAsyncAlgorithms,
                .swiftArgumentParser,
                .swiftLog,
                .swiftNumerics,
            ],
        ] as [[TestPackageIdentity]]
    )
    func test1(identities: [TestPackageIdentity]) async throws {

        let identities = identities.map(\.rawValue)
        var uninstallCommand = try SwiftScriptUninstall.parse(identities)
        uninstallCommand.noBuild = true
        uninstallCommand.appEnv = appEnv

        // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
        try await uninstallCommand.wrappedRun()

        let installedPackageIdentities = try await validateAndLoadInstalledPackages()
            .map(\.identity)
            .toSet()

        #expect(
            installedPackageIdentities.symmetricDifference(originalInstalledIdentities) == identities.toSet()
        )

    }


    @Test("Package Not Installed")
    func test2() async throws {

        var uninstallCommand = try SwiftScriptUninstall.parse(["not-installed1", "not-installed2"])
        uninstallCommand.noBuild = true
        uninstallCommand.appEnv = appEnv

        await #expect(throws: Error.self, "Expect error when uninstalling packages that are not installed") {
            // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
            try await uninstallCommand.wrappedRun()
        }

        let installedPackageIdentities = try await validateAndLoadInstalledPackages()
            .map(\.identity)
            .toSet()

        #expect(
            installedPackageIdentities == originalInstalledIdentities, 
            "No package should be removed"
        )

    }

}