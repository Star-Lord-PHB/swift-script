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