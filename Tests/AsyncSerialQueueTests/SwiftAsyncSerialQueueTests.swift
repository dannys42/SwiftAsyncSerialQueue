import XCTest
@testable import AsyncSerialQueue

final class SwiftAsyncSerialQueueTests: XCTestCase {
    fileprivate var dataHelper = ThreadSafeIntArray()

    override func setUp() async throws {
        self.dataHelper.clear()
    }
    
    func testThat_NormalTasks_WillBeNotOrdered() async throws {
        let numberOfIterations = 200
        let expectedValue: [Int] = .sequence(numberOfIterations)

        let dataHelper = self.dataHelper

        await withTaskGroup(of: Void.self) { group in
            for n in 0..<numberOfIterations {
                group.addTask {
                    try? await Task.sleep(nanoseconds: .random(in: 1...100))
                    dataHelper.append(n)
                }
            }

        }

        let observedValue = self.dataHelper.values()
        XCTAssertNotEqual(observedValue, expectedValue)
    }
    
    func testThat_TasksInAsyncSerialQueue_WillBeOrdered() async throws {
        let numberOfIterations = 200
        let expectedValue: [Int] = .sequence(numberOfIterations)

        let serialQueue = AsyncSerialQueue()

        let dataHelper = self.dataHelper

        for n in 0..<numberOfIterations {
            serialQueue.async {
                dataHelper.append(n)
            }
        }

        await serialQueue.wait()

        let observedValue = self.dataHelper.values()
        XCTAssertEqual(observedValue, expectedValue)
    }


    func testThat_CancelCompletionHandler_WillExecute_AfterQueuedBlock() async throws {
        let serialQueue = AsyncSerialQueue()
        serialQueue.async {
            try? await Task.sleep(for: .seconds(2))
        }

        let expectation = XCTestExpectation(description: "cancel completion handler")
        serialQueue.cancel {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation])
    }

    func testThat_CancelCompletionHandler_WillExecute_WithNoQueuedBlock() async throws {
        let serialQueue = AsyncSerialQueue()

        let expectation = XCTestExpectation(description: "cancel completion handler")
        serialQueue.cancel() {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }


    func testThat_CancelledQueue_WillNoLongerExecute() async throws {
        let serialQueue = AsyncSerialQueue()

        serialQueue.async {
            try? await Task.sleep(for: .seconds(3))
        }
        await serialQueue.cancel()

        let dataHelper = self.dataHelper
        serialQueue.async {
            dataHelper.append(1)
        }

        await serialQueue.wait()

        let observedValue = self.dataHelper.values()

        XCTAssertTrue(observedValue.isEmpty)
        XCTAssertEqual(serialQueue.state, .stopped)
    }
    
    #if false
    func testThat_RestartedQueue_WillExecute() async throws {
        let serialQueue = AsyncSerialQueue()
        let expectedValue = [0, 1]

        self.dataHelper.append(0)
        
        serialQueue.async {
            try? await Task.sleep(for: .seconds(3))
            print("sleeping task stopped  (cancelled: \(Task.isCancelled))")
        }
        await serialQueue.cancel()
        try await serialQueue.restart()
        
        serialQueue.async {
            self.dataHelper.append(1)
        }

        await serialQueue.wait()

        let observedValue = self.dataHelper.values()

        XCTAssertEqual(observedValue, expectedValue)
        XCTAssertEqual(serialQueue.state, .running)
    }
    #endif

    func testThat_MultipleAsync_WillStopExecuting_WhenCancelled() async throws {
        let shouldRun = await TestConfiguration.shared.shouldRunAllTests()
        try XCTSkipUnless(shouldRun, "Don't run in CI as this may not be consistent.")

        let serialQueue = AsyncSerialQueue()
        let numberOfIterations = 200

        let dataHelper = self.dataHelper

        for n in 0..<numberOfIterations {
            Task.detached {
                try? await Task.sleep(nanoseconds: .random(in: 1_000_000...10_000_000))
                serialQueue.async {
                    dataHelper.append(n)
                }
            }
        }
        try? await Task.sleep(nanoseconds: 5_000_000)

        await serialQueue.cancel()
        
        let numberOfValues = self.dataHelper.values().count
        XCTAssertGreaterThan(numberOfValues, 0)
        XCTAssertLessThan(numberOfValues, numberOfIterations)
    }
}
