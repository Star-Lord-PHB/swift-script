//
//  Run.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/26.
//

import ArgumentParser
import FoundationPlus
import SwiftCommand


struct SwiftScriptRun: SwiftScriptWrappedCommand {
    
    static let configuration: CommandConfiguration = .init(commandName: "run")
    
    @Argument(
        help: "path to the script", 
        completion: .file(extensions: ["swift"]),
        transform: FilePath.init(_:)
    )
    var scriptPath: FilePath
    
    @Option(name: .customLong("Xbuild"), parsing: .singleValue, help: #"Pass flag through to "swift build" command"#)
    var swiftArguments: [String] = []
    
    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "strictly eliminate all console outputs that are not from the script, default to false")
    var quiet: Bool = false

    @Argument(parsing: .captureForPassthrough, help: "Pass arguments through to the script")
    var arguments: [String] = []

    var appEnv: AppEnv = .fromEnv()
    var logger: Logger = .init()

    
    func wrappedRun() async throws {
        
        logger.printDebug("Identifying type of script")
        let scriptType = try await ScriptType.of(fileAt: scriptPath)
        logger.printDebug("Script type identified as \"\(scriptType)\"")
        
        let scriptBuildPath = appEnv.scriptBuildPath(ofType: scriptType)
        let scriptExecPath = appEnv.makeExecTempPath()
        logger.printDebug("Allocated executation path: \(scriptExecPath)")
        
        registerCleanUp(when: .always) {
            logger.printDebug("Cleaning script executable")
            try? await FileManager.default.removeItem(at: scriptExecPath)
            logger.printDebug("Cleaning script source")
            try? await appEnv.cleanScriptsWithPlaceholderScript()
        }
        
        try await appEnv.withProcessLock {

            logger.printDebug("Cleaning old script")
            try await appEnv.cleanOldScripts()
            logger.printDebug("Copying script to build path")
            try await FileManager.default.copyItem(at: scriptPath, to: scriptBuildPath)
            
            logger.printDebug("Building runner with arguments: \(swiftArguments)")
            if quiet {
                try await appEnv.buildRunnerPackage(arguments: swiftArguments, verbose: verbose)
            } else {
                try await withLoadingIndicator("Building") {
                    try await appEnv.buildRunnerPackage(arguments: swiftArguments, verbose: verbose)
                }
            }
            
            logger.printDebug("Moving executable to allocated execution path")
            try await FileManager.default.moveItem(at: appEnv.executableProductPath, to: scriptExecPath)
            
        }
        
        logger.printDebug("Executing script at \(scriptExecPath) with arguments: \(arguments)")
        try await appEnv.runExecutable(at: scriptExecPath, arguments: arguments)
        
    }
    
}
