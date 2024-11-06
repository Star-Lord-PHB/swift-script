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

    var appEnv: AppEnv = .default

    
    mutating func wrappedRun() async throws {
        
        let scriptUrl = URL(fileURLWithPath: script)
        
        printLog("Identifying type of script")
        let scriptType = try await ScriptType.of(fileAt: scriptUrl)
        printLog("Script type identified as \"\(scriptType)\"")
        
        let scriptBuildUrl = appEnv.scriptBuildUrl(ofType: scriptType)
        let scriptExecUrl = appEnv.makeExecTempUrl()
        printLog("Allocated executation path: \(scriptExecUrl.compactPath(percentEncoded: false))")
        
        registerCleanUp(when: .always) { [verbose] in
            if verbose { print("Cleaning script executable".skyBlue) }
            try? await FileManager.default.remove(at: scriptExecUrl)
        }
        
        try await appEnv.withProcessLock {

            printLog("Cleaning old script")
            try await appEnv.cleanOldScripts()
            printLog("Copying script to build path")
            try await FileManager.default.copy(scriptUrl, to: scriptBuildUrl)
            
            printLog("Building runner with arguments: \(swiftArguments)")
            try await appEnv.buildRunnerPackage(arguments: swiftArguments, verbose: verbose)
            
            printLog("Moving executable to allocated execution path")
            try await FileManager.default.move(appEnv.executableProductUrl, to: scriptExecUrl)
            
        }
        
        printLog("Executing script at \(scriptExecUrl.compactPath(percentEncoded: false)) with arguments: \(arguments)")
        try await appEnv.runExecutable(at: scriptExecUrl, arguments: arguments)
        
    }
    
}
