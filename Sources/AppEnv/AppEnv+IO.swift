import FileManagerPlus
import Foundation



extension AppEnv {

    private struct AppConfigCodingStructure: Codable {
        var swiftVersion: String?
        var macosVersion: String?
    }

    func loadAppConfig() async throws -> AppConfig {

        try Task.checkCancellation()

        let structure = try await JSONDecoder().decode(
            AppConfigCodingStructure.self,
            from: .read(contentsOf: configFileUrl)
        )
#if os(macOS)
        try Task.checkCancellation()
        let macosVersion = if let str = structure.macosVersion {
            Version(string: str) ?? fetchMacosVersion()
        } else {
            fetchMacosVersion()
        }
#endif
        try Task.checkCancellation()
        let swiftVersion = if let str = structure.swiftVersion {
            try await Version(string: str).unwrap(or: { try await fetchSwiftVersion() })
        } else {
            try await fetchSwiftVersion()
        }

#if os(macOS)
        return .init(
            macosVersion: macosVersion,
            swiftVersion: swiftVersion
        )
#else
        return .init(
            swiftVersion: swiftVersion
        )
#endif

    }

    func saveAppConfig(_ config: AppConfig) async throws {

        try Task.checkCancellation()

        let structure = AppConfigCodingStructure(
            swiftVersion: config.swiftVersion.description,
            macosVersion: config.macosVersion.description
        )
        try await JSONEncoder().encode(structure).write(to: configFileUrl)

    }

    func loadInstalledPackages() async throws -> [InstalledPackage] {
        try Task.checkCancellation()
        return try await JSONDecoder().decode(
            [InstalledPackage].self,
            from: .read(contentsOf: installedPackagesUrl)
        )
    }

    func saveInstalledPackages(_ packages: [InstalledPackage]) async throws {
        try Task.checkCancellation()
        return try await JSONEncoder().encode(packages).write(to: installedPackagesUrl)
    }

    func loadResolvedDependencyVersionList() async throws -> [ResolvedDependencyVersion] {

        try await resolveRunnerPackage()
        let actualInstalledPackageIdentities = try await loadInstalledPackages().map(\.identity).toSet()

        try Task.checkCancellation()

        return try await JSONDecoder().decode(
            ResolvedDependencyVersionList.self,
            from: .read(contentsOf: runnerResolvedPackagesUrl)
        )
        .dependencies
        .filter { actualInstalledPackageIdentities.contains($0.identity) }

    }

}



extension AppEnv {

    func updatePackageManifest(
        installedPackages: [InstalledPackage],
        config: AppConfig
    ) async throws {
        try Task.checkCancellation()
        let manifest = PackageManifestTemplate.makeRunnerPackageManifest(
            installedPackages: installedPackages,
            config: config
        )
        try await Data(manifest.utf8).write(to: runnerPackageManifestUrl)
    }

    func loadPackageManifes() async throws -> Data {
        try Task.checkCancellation()
        return try await .read(contentsOf: runnerPackageManifestUrl)
    }

    func createTempPackage(
        at url: URL,
        packageUrl: URL,
        requirement: InstalledPackage.Requirement,
        config: AppConfig
    ) async throws {
        try await createNewPackage(at: url)
        let manifest = PackageManifestTemplate.makeTempPackageManifest(
            packageUrl: packageUrl,
            requirement: requirement,
            config: config
        )
        try Task.checkCancellation()
        try await Data(manifest.utf8).write(to: url.appendingCompat(path: "Package.swift"))
    }


    func cleanOldScripts() async throws {
        try Task.checkCancellation()
        let files = try await FileManager.default.directoryEntries(at: runnerPackageUrl.appendingCompat(path: "Sources"))
        for url in files {
            try Task.checkCancellation()
            try await FileManager.default.remove(at: url)
        }
    }

}
