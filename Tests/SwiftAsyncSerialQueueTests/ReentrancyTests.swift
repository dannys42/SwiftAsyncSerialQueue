//
//  ReentrancyTests.swift
//  
//
//  Created by Danny Sung on 11/4/23.
//

import XCTest
import SwiftAsyncSerialQueue

final class ReentrancyTests: XCTestCase {
    
    /// Not checking for order here, just that we're thread-safe
    func testThat_QueueingBlocks_IsThreadSafe() async throws {
        let numberOfThreads = 20
        let numberOfIterations = 10_000
        let expectedValue = numberOfThreads * numberOfIterations
        let serialQueue = AsyncSerialQueue()
        let g = DispatchGroup()
        let counter = ThreadSafeCounter()

        for _ in 0..<numberOfThreads {
            g.enter()
            Thread {
                defer { g.leave() }
                for _ in 0..<numberOfIterations {
                    serialQueue.async {
                        try? await Task.sleep(for: .nanoseconds(1)) // give up a time-slice
                        counter.increment()
                    }
                }

                let semaphore = DispatchSemaphore(value: 0)
                serialQueue.async {
                    semaphore.signal()
                }
                semaphore.wait()
            }.start()
        }

        await g.wait()

        let observedValue = counter.value

        XCTAssertEqual(observedValue, expectedValue)
    }

    func testThat_MultipleCancellationsAcrossThreads_WillExecute() async throws {
        let serialQueue = AsyncSerialQueue()
        let numberOfThreads = 10
        let numberOfIterations = 10
        let expectedValue = numberOfThreads * numberOfIterations
        let g = DispatchGroup()
        let counter = ThreadSafeCounter()

        serialQueue.async {
            try? await Task.sleep(for: .seconds(5)) // 2 is arbitrary -- needs to be long enough to execute the loops below.
        }

        for _ in 0..<numberOfThreads {
            g.enter()
            Thread {
                defer { g.leave() }

                let semaphore = DispatchSemaphore(value: 0)
                let threadG = DispatchGroup()
                for _ in 0..<numberOfIterations {
                    threadG.enter()
                    serialQueue.cancel {
                        defer { threadG.leave() }
                        counter.increment()

                    }
                }

                threadG.notify(queue: .global()) {
                    semaphore.signal()
                }
                semaphore.wait()
            }.start()
        }


        await g.wait()

        let observedValue = counter.value

        XCTAssertEqual(observedValue, expectedValue)
    }
}


