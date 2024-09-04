//
//  ExecutorRetainCycleTests.swift
//
//
//  Created by Danny Sung on 6/18/24.
//

import XCTest
@testable import AsyncSerialQueue

final class ExecutorRetainCycleTests: XCTestCase {


//    func testThat_UnusedExecutor_HasNoStrongReferences() async throws {
//        var executor = Executor()
//
//        let hasStrongReferences = isKnownUniquelyReferenced(&executor)
//        XCTAssertFalse( hasStrongReferences )
//    }

    func testThat_UnusedExecutor_WillRelease() async throws {

        let weakBox = await WeakBox<Executor> {
            Executor()
        }

        XCTAssertTrue(weakBox.isNil)
    }

    func testThat_QueuedExecutor_WillRelease() async throws {
        let weakBox = await WeakBox<Executor> {
            let executor = Executor()

            await withCheckedContinuation { continuation in
                executor.async {
                    try? await Task.sleep(for: .milliseconds(125))

                    continuation.resume()
                }
            }

            return executor
        }

        XCTAssertTrue(weakBox.isNil)
    }


    func testThat_HoldStrongReference_WillNotBeNil() async throws {
        let executor = Executor()

        let weakBox = await WeakBox<Executor> {
            return executor
        }

        XCTAssertFalse(weakBox.isNil)
    }
}
