//
//  SendableWrapper.swift
//  swift-script
//
//  Created by Star_Lord_PHB on 2024/11/3.
//

struct SendableWrapper<Wrapped>: @unchecked Sendable {
    var value: Wrapped
}

