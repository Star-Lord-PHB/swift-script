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
            from: .read(contentAt: configFilePath)
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
        try await JSONEncoder().encode(structure).write(to: configFilePath)

    }

    func loadInstalledPackages() async throws -> [InstalledPackage] {
        try Task.checkCancellation()
        return try await JSONDecoder().decode(
            [InstalledPackage].self,
            from: .read(contentAt: installedPackagesPath)
        )
    }

    func saveInstalledPackages(_ packages: [InstalledPackage]) async throws {
        try Task.checkCancellation()
        return try await JSONEncoder().encode(packages).write(to: installedPackagesPath)
    }

    func loadResolvedDependencyVersionList() async throws -> [ResolvedDependencyVersion] {

        try await resolveRunnerPackage()
        let actualInstalledPackageIdentities = try await loadInstalledPackages().map(\.identity).toSet()

        try Task.checkCancellation()

        return try await JSONDecoder().decode(
            ResolvedDependencyVersionList.self,
            from: .read(contentAt: runnerResolvedPackagesPath)
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
        try await Data(manifest.utf8).write(to: runnerPackageManifestPath)
    }

    func loadPackageManifes() async throws -> Data {
        try Task.checkCancellation()
        return try await .read(contentAt: runnerPackageManifestPath)
    }


    func cleanOldScripts() async throws {
        try Task.checkCancellation()
        let files = try await FileManager.default.contentsOfDirectory(at: runnerPackagePath.appending("Sources"))
        for path in files {
            try Task.checkCancellation()
            try await FileManager.default.removeItem(at: path)
        }
    }


    func cleanScriptsWithPlaceholderScript() async throws {
        try Task.checkCancellation()
        try await cleanOldScripts()
        try await FileManager.default.createFile(
            at: scriptBuildPath(ofType: .topLevel), 
            with: .init(#"print("Hello SwiftScript!")"#.utf8),
            replaceExisting: true
        )
    }

}



extension AppEnv {

    struct OriginalCache: Sendable {
        var config: AppConfig? = nil 
        var packageManifest: Data? = nil 
        var installedPackages: [InstalledPackage]? = nil 
    }


    func cacheOriginals(
        _ items: PartialKeyPath<OriginalCache>...
    ) async throws -> OriginalCache {
        
        try Task.checkCancellation()

        let items = items.isEmpty ? [\.config, \.packageManifest, \.installedPackages] : items

        var cache = OriginalCache()

        for item in items {
            switch item {
                case \.config:
                    cache.config = try await loadAppConfig()
                case \.packageManifest:
                    cache.packageManifest = try await loadPackageManifes()
                case \.installedPackages:
                    cache.installedPackages = try await loadInstalledPackages()
                default: break
            }
        }

        return cache

    }


    func restoreOriginals(_ cache: OriginalCache) async throws {

        try Task.checkCancellation()

        if let config = cache.config {
            try await saveAppConfig(config)
        }

        if let manifest = cache.packageManifest {
            try await manifest.write(to: runnerPackageManifestPath)
        }

        if let packages = cache.installedPackages {
            try await saveInstalledPackages(packages)
        }

    }

}
