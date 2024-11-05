//
//  Run.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptRun: VerboseLoggableCommand {
    
    static let configuration: CommandConfiguration = .init(commandName: "run")
    
    @Argument(help: "path to the script", completion: .file(extensions: ["swift"]))
    var script: String
    
    @Argument(parsing: .allUnrecognized, help: "Pass arguments through to the script")
    var arguments: [String] = []
    
    @Option(name: .customLong("Xbuild"), parsing: .singleValue, help: #"Pass flag through to "swift build" command"#)
    var swiftArguments: [String] = []
    
    @Flag(name: .shortAndLong)
    var verbose: Bool = false
    
    mutating func wrappedRun() async throws {
        
        let scriptUrl = URL(fileURLWithPath: script)
        
        printLog("Identifying type of script")
        let scriptType = try await ScriptType.of(fileAt: scriptUrl)
        printLog("Script type identified as \"\(scriptType)\"")
        
        let scriptBuildUrl = AppPath.scriptBuildUrl(ofType: scriptType)
        let scriptExecUrl = AppPath.makeExecTempUrl()
        printLog("Allocated executation path: \(scriptExecUrl.compactPath(percentEncoded: false))")
        
        registerCleanUp(when: .always) { [verbose] in
            if verbose { print("Cleaning script executable".skyBlue) }
            try? await FileManager.default.remove(at: scriptExecUrl)
        }
        
        try await ProcessLock.shared.withLock {
            printLog("Cleaning old script")
            try? await FileManager.default.remove(at: scriptBuildUrl)
            printLog("Copying script to build path")
            try await FileManager.default.copy(scriptUrl, to: scriptBuildUrl)
            
            printLog("Building runner with arguments: \(swiftArguments)")
            try await CMD.buildRunnerPackage(arguments: swiftArguments)
            
            printLog("Moving executable to allocated execution path")
            try await FileManager.default.move(AppPath.executableProductUrl, to: scriptExecUrl)
        }
        
        printLog("Executing script at \(scriptExecUrl.compactPath(percentEncoded: false)) with arguments: \(arguments)")
        try await CMD.runExecutable(at: scriptExecUrl, arguments: arguments)
        
    }
    
}
