//
//  VerboseLoggableCommand.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/11/3.
//

import FoundationPlusEssential
import ConcurrencyPlus
import ArgumentParser


nonisolated(unsafe) private var interruptCleanUpOperations: [@MainActor () async -> Void] = []
nonisolated(unsafe) private var normalCleanUpOperations: [@MainActor () async -> Void] = []


protocol VerboseLoggableCommand: AsyncParsableCommand {
    var appEnv: AppEnv { get set }
    var verbose: Bool { get }
    mutating func wrappedRun() async throws
}


extension VerboseLoggableCommand {
    
    var verbose: Bool { false }

    init(appEnv: AppEnv) {
        self.init()
        self.appEnv = appEnv
    }


    mutating func run() async throws {

        do {

            SignalHandler.startSignalListening()

            let localSelf = SendableWrapper(value: self)
            let task = Task {
                var command = localSelf.value
                try await command.wrappedRun()
            }

            SignalHandler.registerTask(task)
            try await task.waitThrowing()

            await normalCleanUp()

            return 

        } catch let error as ExitCode where error == .success {
            await normalCleanUp()
            return          // Do nothing
        } catch let error as CLIError where error.code == 0 {
            await normalCleanUp()
            return          // Do nothing
        } catch let error as CleanExit {
            await normalCleanUp()
            throw error     // Do nothing
        } catch {
            let code = switch error {
                case let error as NSError: error.code.int32Val
                case let error as ExitCode: error.rawValue
                case let error as CLIError: error.code.int32Val
                case let error as ExternalCommandError: error.code
                default: ExitCode.failure.rawValue
            }
            
            printStdErr("Error: \(error.localizedDescription)".red)
            await interruptCleanUp()
            throw ExitCode(code)
        }

    }
    
    
    private func normalCleanUp() async {
        for operation in normalCleanUpOperations.reversed() {
            await operation()
        }
    }
    
    
    private func interruptCleanUp() async {
        guard interruptCleanUpOperations.isNotEmpty else { return }
        print("Cleaning up...")
        for operation in interruptCleanUpOperations.reversed() {
            await operation()
        }
    }
    
    
    func printLog(_ message: String) {
        if verbose {
            print(message.skyBlue)
        }
    }
    
    
    func warningLog(_ message: String) {
        printStdErr(message.yellow)
    }
    
    
    func registerCleanUp(
        when mode: CleanUpMode = .interrupt,
        operation: @MainActor @escaping () async -> Void
    ) {
        if mode == .always || mode == .interrupt {
            interruptCleanUpOperations.append(operation)
            SignalHandler.registerCleanUp(operation: operation)
        }
        if mode == .always || mode == .normalExit {
            normalCleanUpOperations.append(operation)
        }
    }

}



enum CleanUpMode {
    case interrupt, normalExit, always
}
