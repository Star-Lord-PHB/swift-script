import Foundation
import Testing
@testable import SwiftScript



@Suite("Test Concurrent Calls")
final class ConcurrentTest: SwiftScriptTestBase, @unchecked Sendable {

    override init() async throws {
        try await super.init()
        try await setupAppFolderWithTemplate(.empty)
    }


    @Test("Test Concurrent Install")
    func test1() async throws {

        var specs = TestPackage.allCasesWithNoRequirement

        do {

            try await withThrowingTaskGroup(of: Void.self) { group in
            
                for spec in specs {
                    group.addTask {
                        try await self.install(url: spec.url, requirement: spec.requirement)
                    }
                }

                try await group.waitForAll()

            }

            try await check(with: specs)

            print("Block 1 Finished")

        }
        
        do {

            try await withThrowingTaskGroup(of: Void.self) { group in
            
                for spec in specs {
                    group.addTask {
                        try await self.uninstall(identities: spec.identity)
                    }
                }

                try await group.waitForAll()

            }

            specs = []

            try await check(with: specs)

            print("Block 2 Finished")

        }

        do {

            specs = [
                .swiftSystem(.branch("main")),
                .swiftNumerics(.exact("1.0.0")),
                .swiftLog(.upToNextMajor("1.5.1")),
            ]

            try await withThrowingTaskGroup(of: Void.self) { group in
            
                for spec in specs {
                    group.addTask {
                        try await self.install(spec: spec)
                    }
                }

                try await group.waitForAll()

            }

            try await check(with: specs)

            print("Block 3 Finished")

        }

        do {

            try await withThrowingTaskGroup(of: Void.self) { group in
            
                group.addTask {
                    try await self.install(spec: .swiftArgumentParser(.notSpecified))
                }

                group.addTask {
                    try await self.install(spec: .swiftAsyncAlgorithms(.notSpecified))
                }

                group.addTask {
                    try await self.install(spec: .swiftCollections(.notSpecified))
                }

                group.addTask {
                    try await self.update(spec: .swiftSystem(.upToNextMajor("1.4.0")))
                }

                group.addTask {
                    try await self.update(spec: .swiftNumerics(.upToNextMajor("1.0.0")))
                }

                group.addTask {
                    try await self.update(spec: .swiftLog(.upToNextMajor("1.4.0")))
                }

                group.addTask {
                    try await self.runScript()
                }

                group.addTask {
                    try await self.runScript()
                }

                try await group.waitForAll()

            }

            specs = [
                .swiftSystem(.upToNextMajor("1.4.0")),
                .swiftNumerics(.upToNextMajor("1.0.0")),
                .swiftLog(.upToNextMajor("1.4.0")),
                .swiftArgumentParser(.notSpecified),
                .swiftAsyncAlgorithms(.notSpecified),
                .swiftCollections(.notSpecified),
            ]

            try await check(with: specs)

            print("Block 4 Finished")

        }

    }

}


extension ConcurrentTest {

    fileprivate func install(url: URL, requirement: Requirement = .notSpecified) async throws {
        var installCommand = try SwiftScriptInstall.parse([url.absoluteString] + requirement.cmdArgs)
        installCommand.appEnv = appEnv

        // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
        try await installCommand.wrappedRun()
    }


    fileprivate func install(spec: TestPackage) async throws {
        try await install(url: spec.url, requirement: spec.requirement)
    }


    fileprivate func uninstall(identities: String...) async throws {
        var uninstallCommand = try SwiftScriptUninstall.parse(identities)
        uninstallCommand.appEnv = appEnv

        // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
        try await uninstallCommand.wrappedRun()
    }


    fileprivate func uninstall(spec: TestPackage) async throws {
        try await uninstall(identities: spec.identity)
    }


    fileprivate func update(identity: String, requirement: Requirement) async throws {
        var updateCommand = try SwiftScriptUpdate.parse([identity] + requirement.cmdArgs)
        updateCommand.appEnv = appEnv

        // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
        try await updateCommand.wrappedRun()
    }


    fileprivate func update(spec: TestPackage) async throws {
        try await update(identity: spec.identity, requirement: spec.requirement)
    }


    fileprivate func runScript() async throws {
        print(try await FileManager.default.directoryEntries(at: Bundle.module.resourceURL!))
        let scriptUrl = Bundle.module.resourceURL!
            .appendingPathComponent("AppFolderTemplates")
            .appendingPathComponent("script")
        var runCommand = try SwiftScriptRun.parse([scriptUrl.compactPath(percentEncoded: false)])
        runCommand.appEnv = appEnv
        // use `wrappedRun()` instead of `run()` to disable the cleanup operations 
        try await runCommand.wrappedRun()
    }

    fileprivate func check(with specs: [TestPackage]) async throws {

        let installedPackages = try await validateAndLoadInstalledPackages()
        let expectedIdentities = specs.map(\.identity).toSet()

        try #require(
            expectedIdentities == installedPackages.map(\.identity).toSet(), 
            "Installed packages not the same as expected"
        )

        for spec in specs {
            let packageInfo = installedPackages.first(where: { $0.identity == spec.identity })!
            validateRequirement(packageInfo.requirement, spec.requirement)
        }

    }

}