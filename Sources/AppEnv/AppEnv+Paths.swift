import ArgumentParser
import FileManagerPlus
import FoundationPlusEssential
import SwiftParser
import SwiftSyntax



extension AppEnv {

    var tempDirPath: FilePath { appBasePath.appending("temp") }

    var runnerPackagePath: FilePath { appBasePath.appending("runner") }

    var runnerPackageManifestPath: FilePath { runnerPackagePath.appending("Package.swift") }

    var runnerResolvedPackagesPath: FilePath {
        runnerPackagePath.appending("Package.resolved")
    }

    var installedPackageCheckoutsPath: FilePath {
        runnerPackagePath.appending(".build/checkouts")
    }

    var installedPackagesPath: FilePath { appBasePath.appending("packages.json") }

    var configFilePath: FilePath { appBasePath.appending("config.json") }

    var execPath: FilePath { appBasePath.appending("exec") }

    var executableProductPath: FilePath {
        runnerPackagePath.appending(".build/release/Runner")
    }

    var processLockPath: FilePath {
        appBasePath.appending("lock.lock")
    }

    var packageSearchListUrl: URL { 
        .init(string: "https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/refs/heads/main/packages.json")!
    }

    func makeTempFolder() async throws -> FilePath {
        try Task.checkCancellation()
        let path = tempDirPath.appending(UUID().uuidString)
        try await FileManager.default.createDirectory(at: path)
        return path
    }

    func withTempFolder<R>(operation: (FilePath) async throws -> R) async throws -> R {
        let filePath = try await makeTempFolder()
        do {
            try Task.checkCancellation()
            let result = try await operation(filePath)
            try await FileManager.default.removeItem(at: filePath)
            return result
        } catch {
            try await FileManager.default.removeItem(at: filePath)
            throw error
        }
    }

    func scriptBuildPath(ofType type: ScriptType) -> FilePath {
        let name = switch type {
            case .mainEntry: "Runner.swift"
            case .topLevel: "main.swift"
        }
        return runnerPackagePath
            .appending("Sources")
            .appending(name)
    }

    func makeExecTempPath() -> FilePath {
        execPath.appending(UUID().uuidString)
    }

    func packageCheckoutPath(of packageIdentity: String) -> FilePath {
        installedPackageCheckoutsPath.appending(packageIdentity)
    }

}
