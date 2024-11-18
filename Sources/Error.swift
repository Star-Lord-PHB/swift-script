//
//  Error.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/10/18.
//

import Foundation


struct CLIError: LocalizedError, CustomStringConvertible {
    let code: Int
    let reason: String
    var description: String { reason }
    var errorDescription: String? { reason }
    init(code: Int = 1, reason: String) {
        self.code = code
        self.reason = reason
    }
}



struct ExternalCommandError: LocalizedError {

    let fullCommand: String
    let code: Int32
    let stderr: String?

    init(fullCommand: String, code: Int32, stderr: String? = nil) {
        self.fullCommand = fullCommand
        self.code = code
        self.stderr = stderr
    }

    init(command: String, args: [String] = [], code: Int32, stderr: String? = nil) {
        self.fullCommand = ([command] + args).joined(separator: " ")
        self.code = code
        self.stderr = stderr
    }

    var errorDescription: String? {
        if let stderr {
            """
            Failed with code \(code) when running `\(fullCommand)`
            \(stderr)
            """
        } else {
            """
            Failed with code \(code) when running `\(fullCommand)`
            """
        }
    }

}


extension ExternalCommandError {

    static func commandNotFound(_ name: String) -> Self { 
        .init(
            command: name,
            code: 127,
            stderr: "command not found: \(name)"
        )
    }

}