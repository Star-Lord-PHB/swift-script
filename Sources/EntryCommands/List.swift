//
//  List.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptList: AsyncParsableCommand {
    
    static let configuration: CommandConfiguration = .init(commandName: "list")
    
    func run() async throws {
        try await CMD.printRunnerDependencies()
    }
    
}
