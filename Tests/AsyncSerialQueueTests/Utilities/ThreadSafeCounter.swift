//
//  ThreadSafeCounter.swift
//  
//
//  Created by Danny Sung on 11/4/23.
//

import Foundation
import os

final class ThreadSafeCounter: @unchecked Sendable {

    private var _counter = OSAllocatedUnfairLock(initialState: 0)

    @discardableResult
    func increment() -> Int {
        self._counter.withLock { counter in
            counter = counter + 1
            return counter
        }
    }

    func clear() {
        self._counter.withLock { counter in
            counter = 0
        }
    }

    var value: Int {
        self._counter.withLock { $0 }
    }
}
