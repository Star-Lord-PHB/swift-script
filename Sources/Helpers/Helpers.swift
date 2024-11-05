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



extension AppPath {

    static func packageIdentity(of packageUrl: URL) -> String {
    
        let pathExtension = packageUrl.pathExtension
        
        return if pathExtension == "git" {
            packageUrl.deletingPathExtension().lastPathComponent.lowercased()
        } else {
            packageUrl.lastPathComponent.lowercased()
        }
        
    }


    static func packageIdentity(of packageUrl: String) throws -> String {
        guard let url = URL(string: packageUrl) else {
            throw ValidationError("Invalid url: \(packageUrl)")
        }
        return packageIdentity(of: url)
    }



    static func packageCheckoutUrl(of packageUrl: URL) -> URL {
        
        let pathExtension = packageUrl.pathExtension
        
        return if pathExtension == "git" {
            AppPath.installedPackageCheckoutsUrl
                .appendingCompat(path: packageUrl.deletingPathExtension().lastPathComponent)
        } else {
            AppPath.installedPackageCheckoutsUrl
                .appendingCompat(path: packageUrl.lastPathComponent)
        }
        
    }



    static func packageCheckoutUrl(of packageUrl: String) throws -> URL {
        guard let url = URL(string: packageUrl) else {
            throw ValidationError("Invalid url: \(packageUrl)")
        }
        return packageCheckoutUrl(of: url)
    }

}



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

