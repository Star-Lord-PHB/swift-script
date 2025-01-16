import FoundationPlusEssential
import SwiftCommand
import FileManagerPlus
import ArgumentParser
#if !canImport(Darwin)
import FoundationNetworking
#endif


extension AppEnv {

    func resolveRunnerPackage(verbose: Bool = false) async throws {
        try await resolvePackage(at: runnerPackagePath, verbose: verbose)
    }


    func cleanRunnerPackage() async throws {
        try await Command.requireInPath("swift")
            .setCWD(runnerPackagePath)
            .addArguments("package", "clean")
            .wait()
    }


    func buildRunnerPackage(
        arguments: [String] = [],
        verbose: Bool = false
    ) async throws {
        try await Command.requireInPath("swift")
            .addArguments(
                "build",
                "--package-path", runnerPackagePath.string,
                "-c", "release"
            )
            .wait(printingOutput: verbose)
    }


    func fetchVersionList(
        of remoteUrl: URL, 
        verbose: Bool = false
    ) async throws -> [(version: SemanticVersion, str: String)] {
        let rawGitTags = try await fetchRemoteTags(at: remoteUrl, verbose: verbose)
        try Task.checkCancellation()
        return rawGitTags
            .compactMap { tag in
                SemanticVersion(string: tag).map { ($0, tag) }
            }
            .sorted(by: \.version)
    }


    func fetchLatestVersion(
        of packageUrl: URL,
        upTo upperVersion: SemanticVersion? = nil,
        verbose: Bool = false
    ) async throws -> SemanticVersion {
        guard 
            let version = try await fetchVersionList(of: packageUrl)
                .last(where: { upperVersion == nil || $0.version < upperVersion! })?
                .version
        else { throw CLIError(reason: "Fail to find any version matched") }
        return version
    }


    func fetchLatestVersionStr(
        of packageUrl: URL,
        upTo upperVersion: SemanticVersion? = nil,
        verbose: Bool = false
    ) async throws -> String {
        guard 
            let str = try await fetchVersionList(of: packageUrl)
                .last(where: { upperVersion == nil || $0.version < upperVersion! })?
                .str
        else { throw CLIError(reason: "Fail to find any version matched") }
        return str
    }


    func fetchPackageFullDescription(
        at remoteUrl: URL, 
        tag: String,
        includeDependencies: Bool = false,
        verbose: Bool = false
    ) async throws -> PackageFullDescription {

        return try await withTempFolder { tempFolderUrl in

            try await clonePackage(remoteUrl, to: tempFolderUrl, tag: tag, verbose: verbose)

            try Task.checkCancellation()

            let description = try await loadPackageDescription(
                of: tempFolderUrl, 
                as: PackageDescription.self
            )

            if includeDependencies {
                try Task.checkCancellation()
                let dependencyText = try await loadPackageDependenciesText(of: tempFolderUrl)
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

            let branch = switch requirement {
                case .branch(let branch): branch 
                case .exact(let version): version
                case .range(let range): try await fetchLatestVersionStr(
                    of: packageRemoteUrl, 
                    upTo: .parse(range.upperBound), 
                    verbose: verbose
                )
            }

            try Task.checkCancellation()

            try await clonePackage(
                packageRemoteUrl, 
                to: tempFolderUrl, 
                tag: branch, 
                verbose: verbose
            )

            try Task.checkCancellation()

            return try await loadPackageDescription(
                of: tempFolderUrl, 
                as: PackageProducts.self
            )

        }

    }


    func runExecutable(at executablePath: FilePath, arguments: [String]) async throws {
        try await Command(executablePath: .init(executablePath.string))
            .addArguments(arguments)
            .wait()
    }


    func printRunnerDependencies() async throws {
        try await Command.requireInPath("swift")
            .addArguments(
                "package", "show-dependencies",
                "--package-path", runnerPackagePath.string
            )
            .wait()
    }


    func loadPackageDependenciesText(of packagePath: FilePath) async throws -> String {

        try await resolvePackage(at: packagePath)

        try Task.checkCancellation()

        let data = try await Command.requireInPath("swift")
            .setCWD(packagePath)
            .addArguments("package", "show-dependencies")
            .getOutputWithFile(at: tempDirPath.appending(UUID().uuidString))

        return String(data: data, encoding: .utf8) ?? ""

    }


    func loadPackageDescription<T: Decodable>(
        of packagePath: FilePath,
        as type: T.Type = T.self
    ) async throws -> T {

        let data = try await Command.requireInPath("swift")
            .setCWD(packagePath)
            .addArguments("package", "describe", "--type", "json")
            .getOutputWithFile(at: tempDirPath.appending(UUID().uuidString))

        return try JSONDecoder().decode(T.self, from: data)

    }


    func fetchSwiftVersion() async throws -> Version {
        try await withTempFolder { folderPath in
            try await createNewPackage(at: folderPath)
            try Task.checkCancellation()
            let versionStr = try await Command.requireInPath("swift")
                .setCWD(folderPath)
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


extension AppEnv {

    func clonePackage(
        _ remoteUrl: URL, 
        to localPath: FilePath, 
        tag: String? = nil,
        verbose: Bool = false
    ) async throws {

        let arguments = if let tag {
            ["clone", "--branch", tag, remoteUrl.absoluteString, "."]
        } else {
            ["clone", remoteUrl.absoluteString]
        }

        try await Command.requireInPath("git")
            .setCWD(localPath)
            .addArguments(arguments)
            .wait(printingOutput: verbose)

    }


    func createNewPackage(at path: FilePath) async throws {
        try await Command.requireInPath("swift")
            .setCWD(path)
            .addArguments("package", "init")
            .wait(printingOutput: false)
    }


    func resolvePackage(at path: FilePath, verbose: Bool = false) async throws {
        try await Command.requireInPath("swift")
            .addArguments(
                "package", "resolve",
                "--package-path", path.string
            )
            .wait(printingOutput: verbose)
    }


    func fetchRemoteTags(at url: URL, verbose: Bool = false) async throws -> [String] {

        let data = try await Command.requireInPath("git")
            .addArguments(
                "ls-remote", "--tags", url.absoluteString
            )
            .getOutputWithFile(at: tempDirPath.appending(UUID().uuidString))

        let output = String(data: data, encoding: .utf8) ?? ""
        if verbose {
            printFromStart(output)
        }
        return output
            .split(separator: "\n")
            .compactMap { $0.split(separator: "/").last }
            .map { String($0) }

    }

}