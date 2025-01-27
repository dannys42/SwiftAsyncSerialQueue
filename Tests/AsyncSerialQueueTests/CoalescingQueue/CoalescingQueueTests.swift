#if canImport(Testing)
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

    @Test("Executing 1 run will execute")
    func testThat_OneRun_WillExecuteOnce() async throws {
        let coalescingQueue = AsyncCoalescingQueue()
        var value: Int = 0
        
        coalescingQueue.run {
            value += 1
        }

        await coalescingQueue.wait()



        #expect(value == 1)
    }

    @Test("Executing 2 runs will execute both")
    func testThat_TwoRuns_WillExecuteTwo() async throws {
        let coalescingQueue = AsyncCoalescingQueue()
        var observedValues: [String] = []
        let expectedValues = [ "one", "two" ]


        coalescingQueue.run {
            observedValues.append("one")
        }
        coalescingQueue.run {
            observedValues.append("two")
        }

        await coalescingQueue.wait()

        #expect(observedValues == expectedValues)
    }

    @Test("Executing 3 long running tasks, only execute the first and last")
    func testThat_ThreeRuns_WillExecuteTwo() async throws {
        let coalescingQueue = AsyncCoalescingQueue()
        var observedValues: [String] = []
        let expectedValues = [ "one", "three" ]


        coalescingQueue.run {
            observedValues.append("one")
            try? await Task.sleep(for: .seconds(1))
        }
        coalescingQueue.run {
            observedValues.append("two")
            try? await Task.sleep(for: .seconds(2))
        }
        coalescingQueue.run {
            observedValues.append("three")
            try? await Task.sleep(for: .seconds(2))
        }

        await coalescingQueue.wait()

        #expect(observedValues == expectedValues)

    }

    @Test("Executing many long running tasks, only the first and last one should run")
    func testThat_ManyRuns_WillExecuteTwo() async throws {
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

        let waitResult = await coalescingQueue.wait(timeout: .seconds(5))
        #expect(waitResult == .completed)

        let endTime = Date.now

//        print("ObservedValue count:\(observedValue.count)")
//        print("ObservedValue \(observedValue)")
        #expect(observedValue == expectedValue)


        #expect(endTime.timeIntervalSince(startTime) < Double(numberOfSecondsPerIteration)*2.5)
    }

}

#endif
