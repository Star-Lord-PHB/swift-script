//
//  PackageManifestTemplate.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/9/26.
//

import FoundationPlusEssential
import FileManagerPlus
import SwiftCommand


private func platformStr(from config: AppConfig) -> String {
#if os(macOS)
        return #".macOS("\#(config.macosVersion)")"#
#else
        return ""
#endif
}


func makeRunnerPackageManifest(
    installedPackages: [InstalledPackage],
    config: AppConfig
) async throws -> String {
    
    #"""
    // swift-tools-version: \#(config.swiftVersion)
    // The swift-tools-version declares the minimum version of Swift required to build this package.
    
    import PackageDescription
    
    let package = Package(
        name: "swift-script-runner",
        platforms: [\#(platformStr(from: config))],
        dependencies: [
            \#(installedPackages.map(to: \.dependencyCommand).joined(separator: ","))
        ],
        targets: [
            // Targets are the basic building blocks of a package, defining a module or a test suite.
            // Targets can depend on other targets in this package and products from dependencies.
            .executableTarget(
                name: "Runner",
                dependencies: [
                    \#(
                        installedPackages
                            .map { package in
                                package.libraries.map { libraryName in
                                    #".product(name: "\#(libraryName)", package: "\#(package.identity)")"#
                                }
                            }
                            .flatMap { $0 }
                            .joined(separator: ",")
                    )
                ]
            ),
        ]
    )
    """#
    
}



func updatePackageManifest(
    installedPackages: [InstalledPackage],
    config: AppConfig
) async throws {
    let manifest = try await makeRunnerPackageManifest(installedPackages: installedPackages, config: config)
    try await Data(manifest.utf8).write(to: AppPath.runnerPackageManifestUrl)
}



func loadPackageManifes() async throws -> Data {
    try await .read(contentsOf: AppPath.runnerPackageManifestUrl)
}



func makeTempPackageManifest(
    packageUrl: URL,
    requirement: InstalledPackage.Requirement,
    config: AppConfig
) async throws -> String {
    let package = InstalledPackage(
        identity: "",
        url: packageUrl,
        libraries: [],
        requirement: requirement
    )
    return #"""
        // swift-tools-version: \#(config.swiftVersion)
        // The swift-tools-version declares the minimum version of Swift required to build this package.
        
        import PackageDescription
        
        let package = Package(
            name: "temp",
            platforms: [\#(platformStr(from: config))],
            dependencies: [
                \#(package.dependencyCommand)
            ],
            targets: [
                .executableTarget(name: "Runner")
            ]
        )
        """#
}



func createTempPackage(
    at url: URL,
    packageUrl: URL,
    requirement: InstalledPackage.Requirement,
    config: AppConfig
) async throws {
    try await CMD.createNewPackage(at: url)
    let manifest = try await makeTempPackageManifest(
        packageUrl: packageUrl,
        requirement: requirement,
        config: config
    )
    try await Data(manifest.utf8).write(to: url.appendingCompat(path: "Package.swift"))
}
