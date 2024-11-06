//
//  List.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptList: VerboseLoggableCommand {
    
    static let configuration: CommandConfiguration = .init(commandName: "list")

    var appEnv: AppEnv = .default
    

    func wrappedRun() async throws {
        try await appEnv.printRunnerDependencies()
    }
    
}
