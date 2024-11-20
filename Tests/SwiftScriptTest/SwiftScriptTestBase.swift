import FoundationPlusEssential
import Testing
import SwiftCommand
@testable import SwiftScript


class SwiftScriptTestBase {

    let appEnv: AppEnv


    init() async throws {

        try await Task.sleep(nanoseconds: .random(in: 0 ... 1_000_000))

        let baseDir = FileManager.default.temporaryDirectory
            .appending(component: "com.serika.swift-script")
            .appendingPathComponent(
                UUID().uuidString + UInt.random(in: UInt.min ... UInt.max).description
            )

        try await FileManager.default.createDirectory(
            at: baseDir, 
            withIntermediateDirectories: true
        )

        self.appEnv = .init(base: baseDir)

    }


    deinit {
        try? FileManager.default.removeItem(at: appEnv.appBaseUrl)
    }

}


extension SwiftScriptTestBase {

    func setupAppFolderWithTemplate(_ template: Template) async throws {
        try await setupAppFolderWithTemplate(ofName: template.rawValue)
    }

    func setupAppFolderWithTemplate(ofName name: String) async throws {

        let template = Bundle.module.resourceURL!
            .appendingPathComponent("AppFolderTemplates/\(name)")

        for content in try await FileManager.default.directoryEntries(at: template)  {
            try await FileManager.default.copy(
                content, 
                to: appEnv.appBaseUrl.appendingCompat(path: content.lastPathComponent)
            )
        }

        guard let cmd = Command.findInPath(withName: "swift")?
            .setCWD(.init(appEnv.runnerPackageUrl.compatPath(percentEncoded: false)))
            .addArguments("package", "resolve")
        else {
            throw ExternalCommandError.commandNotFound("swift")
        }

        let output = try await cmd.setStderr(.pipe).output

        guard output.status.terminatedSuccessfully else {
            throw ExternalCommandError(
                command: cmd.executablePath.string, 
                args: cmd.arguments, 
                code: output.status.exitCode ?? 1, 
                stderr: output.stderr
            )
        }

        try #require(output.status.terminatedSuccessfully == true)

    }

}


extension SwiftScriptTestBase {

    struct InstalledPackageSpec {
        let identity: String
        let url: URL
        let requirement: InstalledPackage.Requirement
    }


    struct DependencyList: Codable {
        let identity: String
        let dependencies: [Dependency]
    }


    struct Dependency: Codable {
        let identity: String
    }


    func validateAndLoadInstalledPackages() async throws -> [InstalledPackageSpec] {

        let installedPackages = try await JSONDecoder().decode(
            [InstalledPackage].self, 
            from: .read(contentsOf: appEnv.installedPackagesUrl)
        )

        guard let cmd = Command.findInPath(withName: "swift")?
            .setCWD(.init(appEnv.runnerPackageUrl.compatPath(percentEncoded: false)))
            .addArguments("package", "show-dependencies", "--format", "json")
        else {
            throw ExternalCommandError.commandNotFound("swift")
        }

        let output = try await cmd.output

        guard output.status.terminatedSuccessfully else {
            throw ExternalCommandError(
                command: cmd.executablePath.string, 
                args: cmd.arguments, 
                code: output.status.exitCode ?? 1, 
                stderr: output.stderr
            )
        }

        let resolvedPackages = try JSONDecoder().decode(
            DependencyList.self, 
            from: output.stdoutData
        ).dependencies

        #expect(installedPackages.map(\.identity).toSet() == resolvedPackages.map(\.identity).toSet())

        return installedPackages.map { packageInfo in
            .init(
                identity: packageInfo.identity, 
                url: packageInfo.url, 
                requirement: packageInfo.requirement
            )
        }

    }


    func validateRequirement(
        _ installedRequirement: InstalledPackage.Requirement, 
        _ expectedRequirement: Requirement
    ) {

        switch (installedRequirement, expectedRequirement) {

            case (.range(let range), .upToNextMajor(let lower, let .some(upper))):
                #expect(SemanticVersion(string: range.lowerBound) == lower)
                #expect(SemanticVersion(string: range.upperBound) == min(upper, .init(major: lower.major + 1, minor: 0, patch: 0)))

            case (.range(let range), .upToNextMajor(let lower, _)):
                #expect(SemanticVersion(string: range.lowerBound) == lower)
                #expect(SemanticVersion(string: range.upperBound) == .init(major: lower.major + 1, minor: 0, patch: 0))

            case (.range(let installedVersion), .upToNextMinor(let lower, let .some(upper))):
                #expect(SemanticVersion(string: installedVersion.lowerBound) == lower)
                #expect(
                    SemanticVersion(string: installedVersion.upperBound)! 
                    == min(upper, .init(major: lower.major, minor: lower.minor + 1, patch: 0))
                )

            case (.range(let installedVersion), .upToNextMinor(let lower, _)):
                #expect(SemanticVersion(string: installedVersion.lowerBound) == lower)
                #expect(
                    SemanticVersion(string: installedVersion.upperBound)! 
                    == .init(major: lower.major, minor: lower.minor + 1, patch: 0)
                )

            case (.range(let installedVersion), .upTo(let upper)):
                #expect(SemanticVersion(string: installedVersion.upperBound) == upper)

            case (.range(let installedVersion), .notSpecified):
                let upperVersion = SemanticVersion(string: installedVersion.upperBound)
                #expect(
                    upperVersion?.minor == 0 && upperVersion?.patch == 0, 
                    "When no specific requirement, the upper bound must be a major version"
                )

            case (.exact(let installedVersion), .exact(let expectedVersion)):
                #expect(SemanticVersion(string: installedVersion) == expectedVersion)

            case (.branch(let installedBranch), .branch(let expectedBranch)):
                #expect(installedBranch == expectedBranch)

            default:
                #expect(Bool(false), "Requirement not matched")

        }

    }

}