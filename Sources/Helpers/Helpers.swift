//
//  Helpers.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/9/27.
//

import Foundation
import FileManagerPlus
import SwiftCommand
import ArgumentParser



extension AsyncSequence {
    
    func collectAsArray() async throws -> [Element] {
        try await self.reduce(into: []) { arr, element in
            arr.append(element)
        }
    }
    
}



extension Optional {
    
    func unwrap(or operation: () async throws -> Wrapped) async rethrows -> Wrapped {
        return if let value = self {
            value
        } else {
            try await operation()
        }
    }
    
}



extension URL {

    static func parse(_ string: String) throws -> URL {
        if let url = URL(string: string) {
            return url
        } else {
            throw ValidationError("Invalid URL: \(string)")
        }
    }

}


struct StdStream: TextOutputStream {

    private let fileHandle: FileHandle

    func write(_ string: String) {
        fileHandle.write(Data(string.utf8))
    }

    static let standardOutput = StdStream(fileHandle: .standardOutput)
    static let standardError = StdStream(fileHandle: .standardError)

}


func printStdErr(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    var standardError = StdStream.standardError
    print(items, separator: separator, terminator: terminator, to: &standardError)
}


func printOverlapping(_ message: String) {
    print("\u{001B}[2K\r\(message)", terminator: "")
    fflush(stdout)
}


func withLoadingIndicator<R>(_ message: String, operation: () async throws -> R) async throws -> R {
    let loadingTask = Task { 
        try await printLoading(message)
    }
    return try await execute {
        try await operation()
    } finally: {
        await loadingTask.cancelAndWait()
    }
}


func printLoading(_ message: String) async throws -> Never {
    defer { printOverlapping("") }
    while true {
        for char in ["|", "/", "-", "\\"] {
            printOverlapping("\(char) \(message)".lightGray)
            try await Task.sleep(nanoseconds: 200_000_000)
        }
    }
}


func execute<R>(
    operation: () async throws -> R, 
    finally cleanUp: @escaping () async throws -> Void
) async throws -> R {
    let wrapped = SendableWrapper(value: cleanUp)
    do {
        let result = try await operation()
        try await Task {
            try await wrapped.value()
        }.value
        return result
    } catch {
        try await Task {
            try await wrapped.value()
        }.value
        throw error
    }   
}


func packageIdentity(of packageUrl: URL) -> String {

    let pathExtension = packageUrl.pathExtension

    return if pathExtension == "git" {
        packageUrl.deletingPathExtension().lastPathComponent.lowercased()
    } else {
        packageUrl.lastPathComponent.lowercased()
    }

}