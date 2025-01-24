//
//  AppConfig.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/2.
//

import Foundation
import FileManagerPlus


struct AppConfig: Equatable, Sendable {
    
    var macosVersion: Version? = nil 
    var swiftVersion: Version? = nil 
    var swiftPath: String? = nil 
    var editorConfig: EditorConfig? = nil

    var swiftFilePath: FilePath? {
        swiftPath.map { .init($0) }
    }
    
}



extension AppConfig: Codable {

    enum CodingKeys: String, CodingKey {
        case macosVersion
        case swiftVersion
        case swiftPath
        case editorConfig
    }


    func encode(to encoder: any Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)

#if os(macOS)     
        try container.encodeIfPresent(macosVersion, forKey: .macosVersion)
#endif
        try container.encodeIfPresent(swiftVersion, forKey: .swiftVersion)
        try container.encodeIfPresent(swiftPath, forKey: .swiftPath)
        try container.encodeIfPresent(editorConfig, forKey: .editorConfig)

    }


    init(from decoder: any Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)

#if os(macOS)
        macosVersion = try container.decodeIfPresent(Version.self, forKey: .macosVersion)
#endif
        swiftVersion = try container.decodeIfPresent(Version.self, forKey: .swiftVersion)
        swiftPath = try container.decodeIfPresent(String.self, forKey: .swiftPath)
        editorConfig = try container.decodeIfPresent(EditorConfig.self, forKey: .editorConfig)

    }

}



struct EditorConfig: Sendable, Equatable, Codable {

    var editorPath: String
    var editorArguments: [String] = []

    var editorFilePath: FilePath { .init(editorPath) }

}