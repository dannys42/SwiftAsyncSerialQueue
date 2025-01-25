//
//  CoalescingQueueTests.swift
//  SwiftAsyncSerialQueue
//
//  Created by Danny Sung on 1/23/25.
//

import Foundation
import Testing
@testable import AsyncSerialQueue

struct CoalescingQueueTests {

    @Test func testThat_DelayedTasks_WillCoalesce() async throws {
        let coalescingQueue = AsyncCoalescingQueue()
        var value: Int = 0
        let numberOfIterations = 20
        let numberOfSecondsPerIteration = 2
        struct RunValue: Equatable, CustomStringConvertible {
            let iteration: Int
            let value: Int

            var description: String {
                "(\(iteration),\(value))"
            }
        }

        // Expect that only the first and last task will always execute
        // Assumption: tasks execution take longer than the queue time
        let expectedValue: [RunValue] = [
            RunValue(iteration: 0, value: 1),
            RunValue(iteration: numberOfIterations-1, value: numberOfSecondsPerIteration),
        ]
        var observedValue: [RunValue] = []

        let startTime = Date.now

        for n in 0..<numberOfIterations {
            coalescingQueue.run {
                value += 1
//                print(" attempting to add: [\(n), \(value)]")
                try? await Task.sleep(for: .seconds(2))

                observedValue.append(RunValue(iteration: n, value: value))
            }
        }

        await coalescingQueue.wait()

        let endTime = Date.now

//        print("ObservedValue count:\(observedValue.count)")
//        print("ObservedValue \(observedValue)")
        #expect(observedValue == expectedValue)


        #expect(endTime.timeIntervalSince(startTime) < Double(numberOfSecondsPerIteration)*2.5)
    }

}
