import FoundationPlusEssential
import ArgumentParser
import FileManagerPlus
import SwiftCommand


struct SwiftScriptEdit: SwiftScriptWrappedCommand {

    static let configuration: CommandConfiguration = .init(
        commandName: "edit",
        abstract: "Edit a script with the editor specified in config",
        discussion: """
            To modify the editor used, use `swiftscript config set editor` command.
            """
    )

    @Argument(
        help: "The path to the script to edit", 
        transform: FilePath.init(_:)
    )
    var scriptPath: FilePath

    var appEnv: AppEnv = .fromEnv()
    var logger: Logger = .init()


    func wrappedRun() async throws {

        let editWorkspacePath = try await appEnv.createNewEditWorkspace()

        registerCleanUp(when: .always) {
            do {
                try FileManager.default.removeItem(at: editWorkspacePath)
            } catch {
                logger.printWarning("""
                    Failed to remove edit workspace at \(editWorkspacePath)
                    \(error)
                    Consider removing it manually or run swiftscript edit --clean
                    """
                )
            }
        }

        let scriptType = try await ScriptType.of(fileAt: scriptPath)
        let name = switch scriptType {
            case .mainEntry: "Script.swift"
            case .topLevel: "main.swift"
        }

        let absoluteScriptPath = if scriptPath.isRelative {
            FileManager.default.currentDirectoryFilePath.appending(scriptPath.components)
        } else {
            scriptPath
        }

        try await FileManager.default.createSymbolicLink(
            at: editWorkspacePath.appending("Sources").appending(name), 
            withDestination: absoluteScriptPath
        )

        if let editorConfig = appEnv.appConfig.editorConfig {
            try await Command(executablePath: editorConfig.editorFilePath)
                .addArguments(editorConfig.editorArguments)
                .addArgument(editWorkspacePath.string)
                .wait()
        } else {
            logger.printDebug("No editor configuration found, trying to use VSCode")
#if os(Windows)
            guard let paths = ProcessInfo.processInfo.environment["Path"]?
                .split(separator: ";").lazy
                .map(FilePath.init) 
            else {
                throw CLIError(reason: "Failed to get PATH environment variable")
            }
            var codePath: FilePath?
            for path in paths {
                codePath = path.appending("code.cmd")
                if (try? await FileManager.default.infoOfItem(at: codePath!))?.isRegularFile == true { break }
                codePath = nil
            }
            guard let codePath else { throw CLIError(reason: "Failed to find VSCode executable in PATH") }
            try await Command.requireInPath("cmd")
                .addArguments("/c", codePath.string, "--wait", "-n", editWorkspacePath.string)
                .wait()
#else 
            try await Command.requireInPath("code")
                .addArguments("--wait", "-n", editWorkspacePath.string)
                .wait()
#endif
        }
        
    
    }

}