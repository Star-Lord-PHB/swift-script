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



extension Command {
    
    func hideAllOutput() -> Command<Stdin, NullOutputDestination, NullOutputDestination> {
        self.setStdout(.null).setStderr(.null)
    }
    
    func wait(printingOutput: Bool = true) async throws {
        if printingOutput {
            let _ = try await self.status
        } else {
            let _ = try await self.hideAllOutput().status
        }
    }
    
    func wait(hidingOutput: Bool) async throws {
        try await self.wait(printingOutput: !hidingOutput)
    }
    
}

