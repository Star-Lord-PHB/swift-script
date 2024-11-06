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



extension PackageProducts {
    
    static func load(from packageUrl: URL) async throws -> Self {
        
        let outputFileUrl = packageUrl.appendingCompat(path: "otuput.txt")
        try await FileManager.default.createFile(at: outputFileUrl, replaceExisting: true)
        
        guard
            let _ = try await Command.findInPath(withName: "swift")?
                .addArguments(
                    "package",
                    "--package-path", packageUrl.compactPath(percentEncoded: false),
                    "describe", "--type", "json"
                )
                .setOutputs(.write(toFile: .init(outputFileUrl.compactPath())))
                .status
        else {
            throw ValidationError("Fail to get package description")
        }
        
        return try await JSONDecoder().decode(
            PackageProducts.self,
            from: .read(contentsOf: outputFileUrl)
        )
        
    }
    
}
