//
//  PackageManifestTemplate.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/9/26.
//

import FoundationPlusEssential
import FileManagerPlus
import SwiftCommand


enum PackageManifestTemplate {

    static func makeRunnerPackageManifest(
        installedPackages: [InstalledPackage],
        swiftVersion: Version,
        macosVersion: Version? = nil 
    ) -> String {
        
        #"""
        // swift-tools-version: \#(swiftVersion)
        // The swift-tools-version declares the minimum version of Swift required to build this package.
        
        import PackageDescription
        
        let package = Package(
            name: "swift-script-runner",
            \#(macosVersion.map { #"platforms: [.macOS("\#($0)")],"# } ?? "")
            dependencies: [
                \#(installedPackages.map(\.dependencyCommand).joined(separator: ","))
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



    static func makeTempPackageManifest(
        packageUrl: URL,
        requirement: InstalledPackage.Requirement,
        swiftVersion: Version,
        macosVersion: Version? = nil 
    ) -> String {
        let package = InstalledPackage(
            identity: "",
            url: packageUrl,
            libraries: [],
            requirement: requirement
        )
        return #"""
            // swift-tools-version: \#(swiftVersion)
            // The swift-tools-version declares the minimum version of Swift required to build this package.
            
            import PackageDescription
            
            let package = Package(
                name: "temp",
                \#(macosVersion.map { #"platforms: [.macOS("\#($0)")],"# } ?? "")
                dependencies: [
                    \#(package.dependencyCommand)
                ],
                targets: [
                    .executableTarget(name: "Runner")
                ]
            )
            """#
    }

}
