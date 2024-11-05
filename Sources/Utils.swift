//
//  Utils.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/9/24.
//

import Foundation


extension URL {
    
    func appendingCompat(path: String) -> URL {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            self.appending(path: path)
        } else {
            self.appendingPathComponent(path)
        }
    }
    
}
