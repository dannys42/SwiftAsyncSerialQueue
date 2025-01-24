//
//  SyncTests.swift
//  SwiftAsyncSerialQueue
//
//  Created by Danny Sung on 1/23/25.
//

import Foundation
import Testing
@testable import AsyncSerialQueue

@Test("Sync will return value")
func syncWillReturnValue() async throws {
    let queue = AsyncSerialQueue()
    let inputValue = "Hello, World!"
    let expectedValue = inputValue

    let observedValue = try await queue.sync {
        try await Task.sleep(for: .milliseconds(10))
        return inputValue
    }

    #expect(observedValue == expectedValue)
}


@Test("Sync will throw value")
func syncWillThrowValue() async throws {
    enum Failures: LocalizedError {
        case failure1
        case failure2
    }

    let queue = AsyncSerialQueue()
    let inputValue = "Hello, World!"

    await #expect(throws: Failures.failure1) {
        try await queue.sync {
            try await Task.sleep(for: .milliseconds(10))

            throw Failures.failure1
            return inputValue
        }
    }
}

