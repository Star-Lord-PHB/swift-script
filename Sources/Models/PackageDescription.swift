//
//  PackageDescription.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/23.
//

import Foundation
import CodableMacro


struct PackageDescription: Codable {

    let name: String
    let platforms: [Platform]
    fileprivate let products: [Product]
    fileprivate let targets: [Target]

    private var libraryProducts: [Product] {
        products.filter { $0.isLibrary }
    }

    private var libraryTargets: [Target] {
        targets.filter { $0.isLibrary }
    }

    var modules: [String] {
        let libraryProducts = Set(libraryProducts.map(\.name))
        return libraryTargets
            .filter { target in
                target.containingProducts.contains(where: { libraryProducts.contains($0) })
            }
            .map(\.name)
    }

}



extension PackageDescription {
    
    struct Product: Codable {
        let name: String
        let targets: [String]
        let type: `Type`
        var isLibrary: Bool { type.library != nil }
    }
    
    
    struct `Type`: Codable {
        let library: [String]?
    }
    
    
    @Codable
    struct Target {
        let name: String
        @CodingField("product_memberships", default: [])
        let containingProducts: [String]
        let type: String
        var isLibrary: Bool { type == "library" }
    }


    struct Platform: Codable, CustomStringConvertible {
        let name: String
        let version: String
        var description: String { "\(name) \(version)" }
    }
    
}



struct PackageFullDescription {

    let name: String
    let url: URL 
    let platforms: [PackageDescription.Platform]
    let products: [PackageDescription.Product]
    let targets: [PackageDescription.Target]
    let dependencyText: String

    private var libraryProducts: [PackageDescription.Product] {
        products.filter { $0.isLibrary }
    }

    private var libraryTargets: [PackageDescription.Target] {
        targets.filter { $0.isLibrary }
    }

    var modules: [String] {
        let libraryProducts = Set(libraryProducts.map(\.name))
        return libraryTargets
            .filter { target in
                target.containingProducts.contains(where: { libraryProducts.contains($0) })
            }
            .map(\.name)
    }

    var identity: String { packageIdentity(of: url) }

}


extension PackageFullDescription {

    init(from packageDescription: PackageDescription, url: URL, dependencyText: String) {
        self.name = packageDescription.name
        self.platforms = packageDescription.platforms
        self.products = packageDescription.products
        self.targets = packageDescription.targets
        self.dependencyText = dependencyText
        self.url = url
    }

}