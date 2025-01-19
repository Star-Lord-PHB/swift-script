//
//  List.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptList: SwiftScriptWrappedCommand {
    
    static let configuration: CommandConfiguration = .init(commandName: "list")

    var appEnv: AppEnv = .fromEnv()
    

    func wrappedRun() async throws {
        try await appEnv.printRunnerDependencies()
    }
    
}
