//
//  AppConfig.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/2.
//

import Foundation
import FileManagerPlus
import CodableMacro


struct AppConfig: Equatable {
    
#if os(macOS)
    var macosVersion: Version
#endif
    var swiftVersion: Version
    
}
