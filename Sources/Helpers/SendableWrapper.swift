//
//  SendableWrapper.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/11/3.
//

import Foundation


struct SendableWrapper<Wrapped>: @unchecked Sendable {
    var value: Wrapped
}


final class Mutex<Value>: @unchecked Sendable {

    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func withLock<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        try lock.withLock {
            try body(&value)
        }
    }

}