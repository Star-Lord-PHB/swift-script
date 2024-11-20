import Foundation
import SwiftCommand
import FileManagerPlus
import ArgumentParser


extension AppEnv {

    func resolvePackage(at url: URL, verbose: Bool = false) async throws {
        try await Command.requireInPath("swift")
            .addArguments(
                "package", "resolve",
                "--package-path", url.compatPath(percentEncoded: false)
            )
            .wait(printingOutput: verbose)
    }


    func resolveRunnerPackage(verbose: Bool = false) async throws {
        try await resolvePackage(at: runnerPackageUrl, verbose: verbose)
    }


    func buildRunnerPackage(
        arguments: [String] = [],
        verbose: Bool = false
    ) async throws {
        try await Command.requireInPath("swift")
            .addArguments(
                "build",
                "--package-path", runnerPackageUrl.compatPath(percentEncoded: false),
                "-c", "release"
            )
            .wait(printingOutput: verbose)
    }


    func createNewPackage(at url: URL) async throws {
        try await Command.requireInPath("swift")
            .setCWD(.init(url.compatPath(percentEncoded: false)))
            .addArguments("package", "init")
            .wait(printingOutput: false)
    }


    func fetchVersionList(of remoteUrl: URL, verbose: Bool = false) async throws -> [SemanticVersion] {
        let gitOutput = try await Command.requireInPath("git")
            .addArguments("ls-remote", "--tags", remoteUrl.absoluteString)
            .getOutput()
        if verbose {
            printFromStart(gitOutput.stdout)
        }
        try Task.checkCancellation()
        return gitOutput.stdout
            .split(separator: "\n")
            .compactMap { $0.split(separator: "/").last }
            .compactMap { SemanticVersion(string: String($0)) }
            .sorted()
    }


    func fetchLatestVersion(
        of packageUrl: URL,
        upTo upperVersion: SemanticVersion? = nil,
        verbose: Bool = false
    ) async throws -> SemanticVersion {
        guard 
            let version = try await fetchVersionList(of: packageUrl)
                .last(where: { upperVersion == nil || $0 < upperVersion! }) 
        else { throw CLIError(reason: "Fail to find any version matched") }
        return version
    }


    func fetchPackageFullDescription(
        at remoteUrl: URL, 
        includeDependencies: Bool = false,
        verbose: Bool = false
    ) async throws -> PackageFullDescription {

        let packageIdentity = packageIdentity(of: remoteUrl)

        return try await withTempFolder { tempFolderUrl in

            try await createTempPackage(
                at: tempFolderUrl,
                packageUrl: remoteUrl,
                requirement: .exact(fetchLatestVersion(of: remoteUrl).description),
                config: loadAppConfig()
            )

            try Task.checkCancellation()

            try await resolvePackage(at: tempFolderUrl, verbose: verbose)

            try Task.checkCancellation()

            let packageCheckoutUrl = tempFolderUrl
                .appendingCompat(path: ".build/checkouts/")
                .appendingCompat(path: packageIdentity)

            let description = try await loadPackageDescription(
                of: packageCheckoutUrl, 
                as: PackageDescription.self
            )

            if includeDependencies {
                try Task.checkCancellation()
                let dependencyText = try await loadPackageDependenciesText(of: packageCheckoutUrl)
                return .init(from: description, url: remoteUrl, dependencyText: dependencyText)
            } else {
                return .init(from: description, url: remoteUrl, dependencyText: "")
            }

        }

    }


    func fetchPackageProducts(
        of packageRemoteUrl: URL,
        requirement: InstalledPackage.Requirement,
        verbose: Bool = false
    ) async throws -> PackageProducts {

        try await withTempFolder { tempFolderUrl in

            try await createTempPackage(
                at: tempFolderUrl,
                packageUrl: packageRemoteUrl,
                requirement: requirement,
                config: loadAppConfig()
            )

            try Task.checkCancellation()

            try await resolvePackage(at: tempFolderUrl, verbose: verbose)

            let packageCheckoutUrl = tempFolderUrl
                .appendingCompat(path: ".build/checkouts/")
                .appendingCompat(path: packageIdentity(of: packageRemoteUrl))

            try Task.checkCancellation()

            return try await loadPackageDescription(
                of: packageCheckoutUrl, 
                as: PackageProducts.self
            )

        }

    }


    func runExecutable(at executableUrl: URL, arguments: [String]) async throws {
        try await Command(executablePath: .init(executableUrl.compatPath(percentEncoded: false)))
            .addArguments(arguments)
            .wait()
    }


    func printRunnerDependencies() async throws {
        try await Command.requireInPath("swift")
            .addArguments(
                "package", "show-dependencies",
                "--package-path", runnerPackageUrl.compatPath(percentEncoded: false)
            )
            .wait()
    }


    func loadPackageDependenciesText(of packageUrl: URL) async throws -> String {

        try await resolvePackage(at: packageUrl)

        try Task.checkCancellation()

        let data = try await Command.requireInPath("swift")
            .setCWD(.init(packageUrl.compatPath(percentEncoded: false)))
            .addArguments("package", "show-dependencies")
            .getOutputWithFile(at: tempUrl.appendingCompat(path: UUID().uuidString))

        return String(data: data, encoding: .utf8) ?? ""

    }


    func loadPackageDescription<T: Decodable>(
        of packageUrl: URL,
        as type: T.Type = T.self
    ) async throws -> T {

        let data = try await Command.requireInPath("swift")
            .setCWD(.init(packageUrl.compatPath(percentEncoded: false)))
            .addArguments("package", "describe", "--type", "json")
            .getOutputWithFile(at: tempUrl.appendingCompat(path: UUID().uuidString))

        return try JSONDecoder().decode(T.self, from: data)

    }


    func fetchSwiftVersion() async throws -> Version {
        try await withTempFolder { folderUrl in
            try await createNewPackage(at: folderUrl)
            try Task.checkCancellation()
            let versionStr = try await Command.requireInPath("swift")
                .setCWD(.init(folderUrl.compatPath(percentEncoded: false)))
                .addArguments("package", "tools-version")
                .getOutput().stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let version = Version(string: versionStr) else {
                throw CLIError(reason: "Fail to parse swift version: \(versionStr)")
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

    func searchPackage(of identity: String) async throws -> URL? {
        let identity = identity.trimmingCharacters(in: .whitespaces).lowercased()
        let (data, response) = try await URLSession.shared.data(from: packageSearchListUrl)
        guard 
            let response = response as? HTTPURLResponse,
            response.statusCode >= 200 && response.statusCode < 300
        else {
            throw CLIError(reason: "Fail to fetch package list, please report it as an bug")
        }
        guard let packageList = try? JSONDecoder().decode([URL].self, from: data) else {
            throw CLIError(reason: "Fail to decode package list, please report it as an bug")
        }
        return packageList.first(where: { packageIdentity(of: $0) == identity })
    }

}