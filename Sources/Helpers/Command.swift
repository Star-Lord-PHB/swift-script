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
        let status = try await process.status

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

    func getOutput() async throws -> ProcessOutput where Stdout == PipeOutputDestination {
        let output = try await self.output
        guard !output.status.terminatedSuccessfully else { return output }
        throw ExternalCommandError(
            command: self.executablePath.string,
            args: self.arguments,
            code: output.status.exitCode ?? ExitCode.failure.rawValue,
            stderr: output.stderr ?? ""
        )
    }


    func getOutput() async throws -> ProcessOutput where Stdout == UnspecifiedOutputDestination {
        let output = try await self.output
        guard !output.status.terminatedSuccessfully else { return output }
        throw ExternalCommandError(
            command: self.executablePath.string,
            args: self.arguments,
            code: output.status.exitCode ?? ExitCode.failure.rawValue,
            stderr: output.stderr ?? ""
        )
    }


    func getOutputWithFile(
        at tempFileUrl: URL, 
        removeTempFile: Bool = true
    ) async throws -> Data {
        try await FileManager.default.createFile(at: tempFileUrl, replaceExisting: true)
        return try await execute {
            try await self
                .setOutputs(.write(toFile: .init(tempFileUrl.compactPath(percentEncoded: false))))
                .wait()
            return try await .read(contentsOf: tempFileUrl)
        } finally: {
            if removeTempFile {
                try FileManager.default.removeItem(at: tempFileUrl)
            }
        }
    }
    
}