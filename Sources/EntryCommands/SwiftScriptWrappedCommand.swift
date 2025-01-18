//
//  SwiftScriptWrappedCommand.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/11/3.
//

import FoundationPlusEssential
import ConcurrencyPlus
import ArgumentParser


nonisolated(unsafe) private var interruptCleanUpOperations: [@MainActor () async -> Void] = []
nonisolated(unsafe) private var normalCleanUpOperations: [@MainActor () async -> Void] = []


protocol SwiftScriptWrappedCommand: AsyncParsableCommand {
    var appEnv: AppEnv { get set }
    var verbose: Bool { get }
    var logger: Logger { get }
    mutating func wrappedRun() async throws
}


extension SwiftScriptWrappedCommand {
    
    var verbose: Bool { false }
    var logger: Logger { .init() }

    init(appEnv: AppEnv) {
        self.init()
        self.appEnv = appEnv
    }


    mutating func run() async throws {

        do {

            SignalHandler.startSignalListening()

            try await appEnv.initialize()
            logger.initialize(verbose: verbose)

            let localSelf = SendableWrapper(value: self)
            let task = Task {
                var command = localSelf.value
                try await command.wrappedRun()
                try Task.checkCancellation()
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
        } catch _ as CancellationError {
            printStdErr("\nUser Aborted".red)
            await interruptCleanUp()
            let signal = SignalHandler.signal.withLock { $0 }
            throw if signal != -1 {
                ExitCode(128 + signal)
            } else {
                ExitCode.failure
            }
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
        try? await withLoadingIndicator("Cleaning up...") {
            for operation in interruptCleanUpOperations.reversed() {
                await operation()
            }
        }
    }
    
    
    func registerCleanUp(
        when mode: CleanUpMode = .interrupt,
        operation: @MainActor @escaping () async -> Void
    ) {
        if mode == .always || mode == .interrupt {
            interruptCleanUpOperations.append(operation)
        }
        if mode == .always || mode == .normalExit {
            normalCleanUpOperations.append(operation)
        }
    }

}



enum CleanUpMode {
    case interrupt, normalExit, always
}
