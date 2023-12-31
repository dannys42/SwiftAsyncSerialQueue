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

        await withTaskGroup(of: Void.self) { group in
            for n in 0..<numberOfIterations {
                group.addTask {
                    self.dataHelper.append(n)
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

        for n in 0..<numberOfIterations {
            serialQueue.async {
                self.dataHelper.append(n)
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
        serialQueue.async {
            self.dataHelper.append(1)
        }

        await serialQueue.wait()

        let observedValue = self.dataHelper.values()

        XCTAssertTrue(observedValue.isEmpty)
        XCTAssertEqual(serialQueue.state, .stopped)
    }
}
