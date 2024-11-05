//
//  PackageModules.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/23.
//

import Foundation
import CodableMacro


struct PackageModules: Codable {
    
    let name: String
    private let products: [Product]
    private let targets: [Target]
    
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



extension PackageModules {
    
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
    
}
