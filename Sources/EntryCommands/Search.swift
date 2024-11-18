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

    var appEnv: AppEnv = .default
    
    
    func wrappedRun() async throws {
        throw CLIError(reason: "Not implemented yet")
    }
    
}
