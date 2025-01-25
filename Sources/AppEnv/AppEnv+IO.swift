import FileManagerPlus
import Foundation



extension AppEnv {

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

    func updatePackageManifest(installedPackages: [InstalledPackage]) async throws {
        try Task.checkCancellation()
        let swiftVersion = if let version = appConfig.swiftVersion {
            version
        } else {
            try await fetchSwiftVersion()
        }
#if os(macOS)
        let manifest = PackageManifestTemplate.makeRunnerPackageManifest(
            installedPackages: installedPackages,
            swiftVersion: swiftVersion,
            macosVersion: appConfig.macosVersion ?? fetchMacosVersion()
        )
#else
        let manifest = PackageManifestTemplate.makeRunnerPackageManifest(
            installedPackages: installedPackages,
            swiftVersion: swiftVersion
        )
#endif
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

        let items = (items.isEmpty ? [\.config, \.packageManifest, \.installedPackages] : items).toSet()

        var cache = OriginalCache()

        for item in items {
            switch item {
                case \.config:
                    cache.config = appConfig
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



extension AppEnv {

    func createNewEditWorkspace() async throws -> FilePath {

        try Task.checkCancellation()
        let workSpacePath = try await makeEditWorkspaceDir()

        let manager = FileManager.default

        do {

            try await manager.copyItem(at: runnerPackageManifestPath, to: workSpacePath.appending("Package.swift"))
            try await manager.createDirectory(at: workSpacePath.appending("Sources"))

            let sourcekitConfigDir = workSpacePath.appending(".sourcekit-lsp")
            let sourceKitConfigContent = """
                {
                    "swiftPM": {
                        "configuration": "debug"
                    },
                    "backgroundIndexing": true 
                }
                """
            try await manager.createDirectory(at: sourcekitConfigDir)
            try await manager.createFile(at: sourcekitConfigDir.appending("config.json"), with: .init(sourceKitConfigContent.utf8))

        } catch {
            try? await manager.removeItem(at: workSpacePath)
            throw error
        }

        return workSpacePath


    }

}