// The Swift Programming Language
// https://docs.swift.org/swift-book


import ArgumentParser
import FoundationPlus
import SwiftCommand
import AsyncAlgorithms


@main
struct SwiftScript: AsyncParsableCommand {
    
    static let configuration: CommandConfiguration = .init(
        subcommands: [
            SwiftScriptRun.self,
            SwiftScriptInstall.self,
            SwiftScriptList.self,
            SwiftScriptInfo.self,
            SwiftScriptUninstall.self,
            SwiftScriptUpdate.self,
            SwiftScriptSearch.self,
            SwiftScriptConfig.self,
            SwiftScriptInit.self,
        ],
        defaultSubcommand: SwiftScriptRun.self
    )
    
}
