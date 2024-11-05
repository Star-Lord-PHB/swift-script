//
//  Error.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/18.
//

import Foundation


struct PackageError: LocalizedError {
    
    let reason: String
    
    var errorDescription: String? {
        "PackageError: \(reason)"
    }
    
}
