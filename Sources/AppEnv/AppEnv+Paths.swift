import ArgumentParser
import FileManagerPlus
import FoundationPlusEssential
import SwiftParser
import SwiftSyntax



extension AppEnv {

    var tempUrl: URL { appBaseUrl.appendingCompat(path: "temp") }

    var runnerPackageUrl: URL { appBaseUrl.appendingCompat(path: "runner") }

    var runnerPackageManifestUrl: URL { runnerPackageUrl.appendingCompat(path: "Package.swift") }

    var runnerResolvedPackagesUrl: URL {
        runnerPackageUrl.appendingCompat(path: "Package.resolved")
    }

    var installedPackageCheckoutsUrl: URL {
        runnerPackageUrl.appendingCompat(path: ".build/checkouts")
    }

    var installedPackagesUrl: URL { appBaseUrl.appendingCompat(path: "packages.json") }

    var configFileUrl: URL { appBaseUrl.appendingCompat(path: "config.json") }

    var execUrl: URL { appBaseUrl.appendingCompat(path: "exec") }

    var executableProductUrl: URL {
        runnerPackageUrl.appendingCompat(path: ".build/release/Runner")
    }

    var processLockUrl: URL { processLock.path }

    var packageSearchListUrl: URL { 
        .init(string: "https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/refs/heads/main/packages.json")!
    }

    func makeTempFolder() async throws -> URL {
        let url = tempUrl.appendingCompat(path: UUID().uuidString)
        try await FileManager.default.createDirectory(at: url)
        return url
    }

    func withTempFolder<R>(operation: (URL) async throws -> R) async throws -> R {
        let url = try await makeTempFolder()
        do {
            let result = try await operation(url)
            try await FileManager.default.remove(at: url)
            return result
        } catch {
            try await FileManager.default.remove(at: url)
            throw error
        }
    }

    func scriptBuildUrl(ofType type: ScriptType) -> URL {
        let name =
            switch type {
                case .mainEntry: "Runner.swift"
                case .topLevel: "main.swift"
            }
        return runnerPackageUrl
            .appendingCompat(path: "Sources")
            .appendingCompat(path: name)
    }

    func makeExecTempUrl() -> URL {
        execUrl.appendingCompat(path: UUID().uuidString)
    }

    func packageCheckoutUrl(of packageIdentity: String) -> URL {
        installedPackageCheckoutsUrl.appendingCompat(path: packageIdentity)
    }

}
