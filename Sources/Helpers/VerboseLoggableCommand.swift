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
        } catch let error as ExitCode where error.isSuccess {
            await normalCleanUp()
            return // Do nothing
        } catch {
            print("Error: \(error)".red)
            if interruptCleanUpOperations.isNotEmpty {
                print("Cleaning up...")
                await interruptCleanUp()
            }
            throw ExitCode.failure
        }
    }
    
    
    private func normalCleanUp() async {
        for operation in normalCleanUpOperations.reversed() {
            await operation()
        }
    }
    
    
    private func interruptCleanUp() async {
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
        print(message.yellow)
    }
    
    
    func errorAbort(_ reason: String) throws -> Never {
        throw ValidationError(reason)
    }
    
    
    func printOverlapping(_ message: String) {
        print("\u{001B}[2K\r\(message)", terminator: "")
        fflush(stdout)
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
