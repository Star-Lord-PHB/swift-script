//
//  ConsoleColor.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/11/2.
//

import Foundation


extension String {
    
    var green: String {
        "\u{001B}[0;32m\(self)\u{001B}[0;0m"
    }
    
    var red: String {
        "\u{001B}[0;31m\(self)\u{001B}[0;0m"
    }
    
    var yellow: String {
        "\u{001B}[0;33m\(self)\u{001B}[0;0m"
    }
    
    var skyBlue: String {
        "\u{001B}[0;36m\(self)\u{001B}[0;0m"
    }
    
}
