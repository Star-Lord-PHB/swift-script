//
//  Search.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptSearch: VerboseLoggableCommand {
    
    static let configuration: CommandConfiguration = .init(commandName: "search", shouldDisplay: false)
    
    
    func wrappedRun() async throws {
        try errorAbort("Not implemented yet")
    }
    
}
