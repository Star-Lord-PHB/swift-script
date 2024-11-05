//
//  Commands.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/24.
//

import Foundation
import SwiftCommand
import FileManagerPlus
import ArgumentParser


enum CMD {
    
    static func resolveRunnerPackage(verbose: Bool = false) async throws {
        try await Command.findInPath(withName: "swift")?
            .addArguments(
                "package", "resolve",
                "--package-path", AppPath.runnerPackageUrl.compactPath(percentEncoded: false)
            )
            .wait(printingOutput: verbose)
    }


    static func buildRunnerPackage(
        arguments: [String] = [],
        verbose: Bool = false
    ) async throws {
        try await Command.findInPath(withName: "swift")?
            .addArguments(
                "build",
                "--package-path", AppPath.runnerPackageUrl.compactPath(percentEncoded: false),
                "-c", "release"
            )
            .wait(printingOutput: verbose)
    }
    
    
    static func createNewPackage(at url: URL) async throws {
        try await Command.findInPath(withName: "swift")?
            .setCWD(.init(url.compactPath(percentEncoded: false)))
            .addArguments("package", "init")
            .wait(hidingOutput: true)
    }
    
    
    static func fetchLatestVersion(
        of packageUrl: URL,
        upTo upperVersion: Version? = nil,
        verbose: Bool = false
    ) async throws -> Version {
        let gitOutput = try await Command.findInPath(withName: "git")?
            .addArguments("ls-remote", "--tag", packageUrl.absoluteString)
            .output
        if verbose {
            print(gitOutput?.stdout ?? "")
        }
        let version = gitOutput?.stdout
            .split(separator: "\n")
            .compactMap { $0.split(separator: "/").last }
            .compactMap { Version(string: String($0)) }
            .filter { upperVersion == nil || $0 < upperVersion! }
            .max()
        guard let version else { throw ValidationError("Fail to find any version matched") }
        return version
    }
    
    
    static func fetchLatestVersion(
        of packageUrl: String,
        upTo upperVersion: String? = nil,
        verbose: Bool = false
    ) async throws -> Version {
        guard let url = URL(string: packageUrl) else {
            throw ValidationError("Invalid url: \(packageUrl)")
        }
        if let upperVersion {
            guard let upperVersion = Version(string: upperVersion) else {
                throw ValidationError("Invalid version string: \(upperVersion)")
            }
            return try await fetchLatestVersion(of: url, upTo: upperVersion, verbose: verbose)
        } else {
            return try await fetchLatestVersion(of: url, verbose: verbose)
        }
    }
    
    
    static func fetchPackageProducts(
        of packageRemoteUrl: URL,
        requirement: InstalledPackage.Requirement,
        config: AppConfig,
        verbose: Bool = false
    ) async throws -> PackageProducts {
        
        try await AppPath.withTempFolder { tempFolderUrl in
            
            try await createTempPackage(
                at: tempFolderUrl,
                packageUrl: packageRemoteUrl,
                requirement: requirement,
                config: config
            )
            
            try await Command.findInPath(withName: "swift")?
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
    
    
    static func fetchPackageProducts(
        of packageRemoteUrl: String,
        requirement: InstalledPackage.Requirement,
        config: AppConfig,
        verbose: Bool = false
    ) async throws -> PackageProducts {
        guard let url = URL(string: packageRemoteUrl) else {
            throw ValidationError("Invalid url: \(packageRemoteUrl)")
        }
        return try await fetchPackageProducts(of: url, requirement: requirement, config: config, verbose: verbose)
    }
    
    
    static func runExecutable(at executableUrl: URL, arguments: [String]) async throws {
        try await Command(executablePath: .init(executableUrl.compactPath(percentEncoded: false)))
            .addArguments(arguments)
            .wait()
    }
    
    
    static func printRunnerDependencies() async throws {
        try await Command.findInPath(withName: "swift")?
            .addArguments(
                "package", "show-dependencies",
                "--package-path", AppPath.runnerPackageUrl.compactPath(percentEncoded: false)
            )
            .wait()
    }
    
    
    static func loadPackageDependenciesText(of packageUrl: URL) async throws -> String {
        
        let dependenciesOutputFileUrl = packageUrl.appendingCompat(path: "dependencies_text_output.txt")
        try await grantPermission(forFileAt: dependenciesOutputFileUrl)
        try await FileManager.default.createFile(
            at: dependenciesOutputFileUrl,
            replaceExisting: true
        )
        
        try await Command.findInPath(withName: "swift")?
            .setCWD(.init(packageUrl.compactPath(percentEncoded: false)))
            .addArguments("package", "show-dependencies")
            .setOutputs(.write(toFile: .init(dependenciesOutputFileUrl.compactPath(percentEncoded: false))))
            .wait()
        
        return try await String(
            data: .read(contentsOf: dependenciesOutputFileUrl),
            encoding: .utf8
        ) ?? ""
        
    }
    
    
    static func loadPackageDescription<T: Decodable>(
        of packageUrl: URL,
        as type: T.Type = T.self
    ) async throws -> T {
        
        let packageModulesOutputFileUrl = packageUrl.appendingCompat(path: "package_description_output.txt")
        try await grantPermission(forFileAt: packageModulesOutputFileUrl)
        try await FileManager.default.createFile(
            at: packageModulesOutputFileUrl,
            replaceExisting: true
        )
        
        try await Command.findInPath(withName: "swift")?
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


    static func fetchSwiftVersion() async throws -> Version {
        try await AppPath.withTempFolder { folderUrl in
            try await createNewPackage(at: folderUrl)
            guard
                let versionStr = try await Command.findInPath(withName: "swift")?
                    .setCWD(.init(folderUrl.compactPath(percentEncoded: false)))
                    .addArguments("package", "tools-version")
                    .output.stdout
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            else { throw ValidationError("Fail to fetch swift version") }
            guard let version = Version(string: versionStr) else {
                throw ValidationError("Fail to parse swift version: \(versionStr)")
            }
            return version
        }
    }
    
    private static func grantPermission(forFileAt url: URL) async throws {
        if await FileManager.default.fileExistsAsync(at: url) {
            try await FileManager.default.setInfoAsync(
                .posixPermission,
                to: 0b110110100,
                forItemAt: url
            )
        }
    }
    
}
