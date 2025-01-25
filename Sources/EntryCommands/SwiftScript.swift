// The Swift Programming Language
// https://docs.swift.org/swift-book


import ArgumentParser
import FoundationPlus
import SwiftCommand
import AsyncAlgorithms


@main
struct SwiftScript: AsyncParsableCommand {

    static let version: String = "0.1.0"
    
    static let configuration: CommandConfiguration = .init(
        commandName: "swiftscript",
        abstract: "A tool for running single swift source file as script with 3rd party packages",
        subcommands: [
            SwiftScriptRun.self,
            SwiftScriptInstall.self,
            SwiftScriptList.self,
            SwiftScriptInfo.self,
            SwiftScriptUninstall.self,
            SwiftScriptUpdate.self,
            SwiftScriptSearch.self,
            SwiftScriptConfig.self,
            SwiftScriptEdit.self,
            SwiftScriptInit.self,
        ],
        defaultSubcommand: SwiftScriptRun.self
    )

    @Flag(name: .long, help: "Print version")
    var version: Bool = false


    func validate() throws {
        if version {
            print(Self.version)
            throw ExitCode.success
        }
    }
    
}
