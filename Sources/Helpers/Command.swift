import Foundation
import SwiftCommand
import ArgumentParser


extension Command<UnspecifiedInputSource, UnspecifiedOutputDestination, UnspecifiedOutputDestination> {

    static func requireInPath(_ name: String) throws -> Self {
        guard let command = Command.findInPath(withName: name) else {
            throw ExternalCommandError.commandNotFound(name)
        }
        return command
    }

}


extension Command {

    func wait() async throws {

        let process = try self.spawn()
        let wrapper = SendableWrapper(value: process)

        let status = try await withTaskCancellationHandler {
            try await process.status
        } onCancel: { 
            wrapper.value.interrupt()
        }

        try Task.checkCancellation()

        guard !status.terminatedSuccessfully else { return }

        let stderr = switch process {
            case let process as ChildProcess<Stdin, Stdout, PipeOutputDestination>:
                try await process.stderr.lines.collectAsArray().joined(separator: "\n")
            default: ""
        }

        throw ExternalCommandError(
            command: self.executablePath.string,
            args: self.arguments,
            code: status.exitCode ?? ExitCode.failure.rawValue,
            stderr: stderr
        )

    }

}


extension Command where Stdout == UnspecifiedOutputDestination {

    func wait(printingOutput: Bool) async throws {
        
        if printingOutput {
            return try await self.wait()
        } else {
            return try await self
                .setStdout(.null)
                .setStderr(.pipe)
                .wait()
        }

    }

    func wait(hidingOutput: Bool) async throws {
        try await self.wait(printingOutput: !hidingOutput)
    }

}


extension Command {

    func getOutput() async throws -> ProcessOutput {
        let process = try SendableWrapper(value: self.setOutputs(.pipe).spawn())
        let output = try await withTaskCancellationHandler {
            try await process.value.output
        } onCancel: {
            process.value.interrupt()
        }
        try Task.checkCancellation()
        guard !output.status.terminatedSuccessfully else { return output }
        throw ExternalCommandError(
            command: self.executablePath.string,
            args: self.arguments,
            code: output.status.exitCode ?? ExitCode.failure.rawValue,
            stderr: output.stderr ?? ""
        )
    }


    func getOutputWithFile(at tempFileUrl: URL) async throws -> Data {
        try await FileManager.default.createFile(at: tempFileUrl, replaceExisting: true)
        return try await execute {
            try await self
                .setStdout(.write(toFile: .init(tempFileUrl.compatPath(percentEncoded: false))))
                .setStderr(.pipe)
                .wait()
            try Task.checkCancellation()
            return try await .read(contentsOf: tempFileUrl)
        } finally: {
            try FileManager.default.removeItem(at: tempFileUrl)
        }
    }
    
}