//
//  WeakBox.swift
//  
//
//  Created by Danny Sung on 6/17/24.
//

import os

/// A simple container to hold a weak reference to an object
class WeakBox<T: AnyObject & Sendable>: @unchecked Sendable {
    private let semaphore: DispatchSemaphore
    private(set) weak var value: T?

    var isNil: Bool {
        self.value == nil
    }

    init() {
        self.semaphore = DispatchSemaphore(value: 1)
    }

    convenience init(_ block: () async throws -> T) async rethrows {
        self.init()

        self.value = try await block()
    }

    func setValue(_ value: T?) {
        self.semaphore.wait()
        defer { self.semaphore.signal() }

        self.value = value
    }
}
