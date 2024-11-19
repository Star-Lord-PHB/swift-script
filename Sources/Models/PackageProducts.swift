//
//  PackageProducts.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/9/24.
//

import Foundation
import FileManagerPlus
import SwiftCommand
import ArgumentParser


struct PackageProducts: Codable {
    
    let products: [Product]
    
    var libraries: [Product] { products.filter { $0.isLibrary } }
    
}



extension PackageProducts {
    
    struct Product: Codable {
        let name: String
        private let type: `Type`
        var isLibrary: Bool { type.library != nil }
    }
    
    struct `Type`: Codable {
        let library: [String]?
    }
    
}
