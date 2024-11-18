import Foundation
import SwiftCommand
import FileManagerPlus
import ArgumentParser


extension AppEnv {

    func resolveRunnerPackage(verbose: Bool = false) async throws {
        try await Command.requireInPath("swift")
            .addArguments(
                "package", "resolve",
                "--package-path", runnerPackageUrl.compactPath(percentEncoded: false)
            )
            .wait(printingOutput: verbose)
    }


    func buildRunnerPackage(
        arguments: [String] = [],
        verbose: Bool = false
    ) async throws {
        try await Command.requireInPath("swift")
            .addArguments(
                "build",
                "--package-path", runnerPackageUrl.compactPath(percentEncoded: false),
                "-c", "release"
            )
            .wait(printingOutput: verbose)
    }


    func createNewPackage(at url: URL) async throws {
        try await Command.requireInPath("swift")
            .setCWD(.init(url.compactPath(percentEncoded: false)))
            .addArguments("package", "init")
            .wait(printingOutput: false)
    }


    func fetchLatestVersion(
        of packageUrl: URL,
        upTo upperVersion: Version? = nil,
        verbose: Bool = false
    ) async throws -> Version {
        let gitOutput = try await Command.requireInPath("git")
            .addArguments("ls-remote", "--tag", packageUrl.absoluteString)
            .getOutput()
        if verbose {
            print(gitOutput.stdout)
        }
        let version = gitOutput.stdout
            .split(separator: "\n")
            .compactMap { $0.split(separator: "/").last }
            .compactMap { Version(string: String($0)) }
            .filter { upperVersion == nil || $0 < upperVersion! }
            .max()
        guard let version else { throw ValidationError("Fail to find any version matched") }
        return version
    }


    func fetchPackageProducts(
        of packageRemoteUrl: URL,
        requirement: InstalledPackage.Requirement,
        config: AppConfig,
        verbose: Bool = false
    ) async throws -> PackageProducts {

        try await withTempFolder { tempFolderUrl in

            try await createTempPackage(
                at: tempFolderUrl,
                packageUrl: packageRemoteUrl,
                requirement: requirement,
                config: config
            )

            try await Command.requireInPath("swift")
                .addArguments(
                    "package", "resolve",
                    "--package-path", tempFolderUrl.compactPath(percentEncoded: false)
                )
                .wait(printingOutput: verbose)

            let packageCheckoutFolderName = if packageRemoteUrl.pathExtension == "git" {
                packageRemoteUrl.deletingPathExtension().lastPathComponent
            } else {
                packageRemoteUrl.lastPathComponent
            }

            let packageCheckoutUrl = tempFolderUrl
                .appendingCompat(path: ".build/checkouts/")
                .appendingCompat(path: packageCheckoutFolderName)

            return try await PackageProducts.load(from: packageCheckoutUrl)

        }

    }


    func runExecutable(at executableUrl: URL, arguments: [String]) async throws {
        try await Command(executablePath: .init(executableUrl.compactPath(percentEncoded: false)))
            .addArguments(arguments)
            .wait()
    }


    func printRunnerDependencies() async throws {
        try await Command.requireInPath("swift")
            .addArguments(
                "package", "show-dependencies",
                "--package-path", runnerPackageUrl.compactPath(percentEncoded: false)
            )
            .wait()
    }


    func loadPackageDependenciesText(of packageUrl: URL) async throws -> String {

        let dependenciesOutputFileUrl = packageUrl.appendingCompat(path: "dependencies_text_output.txt")
        try await grantPermission(forFileAt: dependenciesOutputFileUrl)
        try await FileManager.default.createFile(
            at: dependenciesOutputFileUrl,
            replaceExisting: true
        )

        try await Command.requireInPath("swift")
            .setCWD(.init(packageUrl.compactPath(percentEncoded: false)))
            .addArguments("package", "show-dependencies")
            .setOutputs(.write(toFile: .init(dependenciesOutputFileUrl.compactPath(percentEncoded: false))))
            .wait()

        return try await String(
            data: .read(contentsOf: dependenciesOutputFileUrl),
            encoding: .utf8
        ) ?? ""

    }


    func loadPackageDescription<T: Decodable>(
        of packageUrl: URL,
        as type: T.Type = T.self
    ) async throws -> T {

        let packageModulesOutputFileUrl = packageUrl.appendingCompat(path: "package_description_output.txt")
        try await grantPermission(forFileAt: packageModulesOutputFileUrl)
        try await FileManager.default.createFile(
            at: packageModulesOutputFileUrl,
            replaceExisting: true
        )

        try await Command.requireInPath("swift")
            .setCWD(.init(packageUrl.compactPath(percentEncoded: false)))
            .addArguments("package", "describe", "--type", "json")
            .setOutputs(
                .write(toFile: .init(packageModulesOutputFileUrl.compactPath(percentEncoded: false)))
            )
            .wait()

        return try await JSONDecoder().decode(
            T.self,
            from: .read(contentsOf: packageModulesOutputFileUrl)
        )

    }


    func fetchSwiftVersion() async throws -> Version {
        try await withTempFolder { folderUrl in
            try await createNewPackage(at: folderUrl)
            let versionStr = try await Command.requireInPath("swift")
                .setCWD(.init(folderUrl.compactPath(percentEncoded: false)))
                .addArguments("package", "tools-version")
                .getOutput().stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let version = Version(string: versionStr) else {
                throw ValidationError("Fail to parse swift version: \(versionStr)")
            }
            return version
        }
    }

#if os(macOS)
    func fetchMacosVersion() -> Version {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return Version(
            major: version.majorVersion,
            minor: version.minorVersion,
            patch: version.patchVersion
        )
    }
#endif

    private func grantPermission(forFileAt url: URL) async throws {
        if await FileManager.default.fileExistsAsync(at: url) {
            try await FileManager.default.setInfoAsync(
                .posixPermission,
                to: 0b110110100,
                forItemAt: url
            )
        }
    }

}