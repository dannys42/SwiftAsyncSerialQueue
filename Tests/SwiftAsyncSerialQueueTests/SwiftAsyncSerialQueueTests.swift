import XCTest
@testable import SwiftAsyncSerialQueue

final class SwiftAsyncSerialQueueTests: XCTestCase {
    fileprivate var dataHelper = DataHelper()

    override func setUp() async throws {
        self.dataHelper.clear()
    }

    func testThat_Tasks_WillBeNotOrdered() async throws {
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

    func testThat_Tasks_WillBeOrdered() async throws {
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
}
