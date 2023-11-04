//
//  DataHelper.swift
//
//
//  Created by Danny Sung on 11/3/23.
//

import Foundation
import os

/// A thread-safe helper class to add elements to an array
class DataHelper: @unchecked Sendable {
    var someArray = OSAllocatedUnfairLock<[Int]>(initialState: [])

    func append(_ value: Int) {
        self.someArray.withLock { array in
            array.append(value)
        }
    }

    func values() -> [Int] {
        self.someArray.withLock { array in
            array
        }
    }

    func clear() {
        self.someArray.withLock { array in
            array.removeAll(keepingCapacity: false)
        }
    }
}

