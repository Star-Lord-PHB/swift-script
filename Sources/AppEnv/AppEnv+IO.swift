import FileManagerPlus
import Foundation



extension AppEnv {

    private struct AppConfigCodingStructure: Codable {
        var swiftVersion: String?
        var macosVersion: String?
    }

    func loadAppConfig() async throws -> AppConfig {

        let structure = try await JSONDecoder().decode(
            AppConfigCodingStructure.self,
            from: .read(contentsOf: configFileUrl)
        )
#if os(macOS)
        let macosVersion =
            if let str = structure.macosVersion {
                Version(string: str) ?? fetchMacosVersion()
            } else {
                fetchMacosVersion()
            }
#endif
        let swiftVersion =
            if let str = structure.swiftVersion {
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

        let structure = AppConfigCodingStructure(
            swiftVersion: config.swiftVersion.description,
            macosVersion: config.macosVersion.description
        )
        try await JSONEncoder().encode(structure).write(to: configFileUrl)

    }

    func loadInstalledPackages() async throws -> [InstalledPackage] {
        try await JSONDecoder().decode(
            [InstalledPackage].self,
            from: .read(contentsOf: installedPackagesUrl)
        )
    }

    func saveInstalledPackages(_ packages: [InstalledPackage]) async throws {
        try await JSONEncoder().encode(packages).write(to: installedPackagesUrl)
    }

    func loadResolvedDependencyVersionList() async throws -> [ResolvedDependencyVersion] {

        try await resolveRunnerPackage()
        let actualInstalledPackageIdentities = try await loadInstalledPackages().map(\.identity).toSet()

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
        let manifest = try await PackageManifestTemplate.makeRunnerPackageManifest(
            installedPackages: installedPackages,
            config: config
        )
        try await Data(manifest.utf8).write(to: runnerPackageManifestUrl)
    }

    func loadPackageManifes() async throws -> Data {
        try await .read(contentsOf: runnerPackageManifestUrl)
    }

    func createTempPackage(
        at url: URL,
        packageUrl: URL,
        requirement: InstalledPackage.Requirement,
        config: AppConfig
    ) async throws {
        try await createNewPackage(at: url)
        let manifest = try await PackageManifestTemplate.makeTempPackageManifest(
            packageUrl: packageUrl,
            requirement: requirement,
            config: config
        )
        try await Data(manifest.utf8).write(to: url.appendingCompat(path: "Package.swift"))
    }


    func cleanOldScripts() async throws {
        let files = try await FileManager.default.directoryEntries(at: runnerPackageUrl.appendingCompat(path: "Sources"))
        for url in files {
            try await FileManager.default.remove(at: url)
        }
    }

}
