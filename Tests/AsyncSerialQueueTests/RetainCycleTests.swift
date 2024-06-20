//
//  File.swift
//  
//
//  Created by Danny Sung on 6/17/24.
//

import XCTest
@testable import AsyncSerialQueue

final class RetainCycleTests: XCTestCase {

//    func testThat_AsyncQueue_WillReleaseImmediately() async throws {
//        weak var serialQueue: AsyncSerialQueue?
//
//        autoreleasepool {
//            let x = AsyncSerialQueue()
//            serialQueue = x
//        }
//
//        print("test: Check for nil")
//        let x = isKnownUniquelyReferenced(&serialQueue)
//        print("count: \(x)")
//        XCTAssertNil(serialQueue)
//    }

    func testThat_QueueWithNoAction_HasNoStrongReferences() async throws {
        var serialQueue = AsyncSerialQueue()

        let hasStrongReferences = isKnownUniquelyReferenced(&serialQueue)
        XCTAssertFalse(hasStrongReferences)
    }

    /*
    func testThat_QueueWithAsyncAction_HasNoStrongReferences() async throws {
        var serialQueue = AsyncSerialQueue()

        let expectation = XCTestExpectation()
        serialQueue.async {
            print("async start")
            defer { print(" async end" )}
            try? await Task.sleep(for: .milliseconds(10))
            expectation.fulfill()
        }

        await fulfillment(of: [expectation])
        try? await Task.sleep(for: .milliseconds(100))

        let hasStrongReferences = isKnownUniquelyReferenced(&serialQueue)
        XCTAssertFalse(hasStrongReferences)
    }
     */


    func testThat_UnusedQueue_WillRelease() async throws {
        let weakBox = await WeakBox<AsyncSerialQueue> {
            AsyncSerialQueue()
        }

        // Need some time for internal async task to finish executing
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(weakBox.isNil)
    }

    func testThat_AsyncedQueue_WillRelease() async throws {
        let weakBox = await WeakBox<AsyncSerialQueue> {
            let serialQueue = AsyncSerialQueue()
            serialQueue.async {
                // This async block may not always be executed because serialQueue may be deinit'd before this gets a chance to run.
            }
            return serialQueue
        }

        // Need to wait here.  Don't care if the block above gets called or not with this test.  This test is only to check for retain cycles.
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(weakBox.isNil)
    }

    func testThat_SyncedQueue_WillRelease() async throws {
        let weakBox = await WeakBox<AsyncSerialQueue> {
            let serialQueue = AsyncSerialQueue()
            await serialQueue.sync {
                // This sync block may not always be executed because serialQueue may be deinit'd before this gets a chance to run.
            }
            return serialQueue
        }

        // Need to wait here.  Don't care if the block above gets called or not with this test.  This test is only to check for retain cycles.
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(weakBox.isNil)
    }

    func testThat_UnusedWaitedQueue_WillRelease() async throws {
        let weakBox = await WeakBox<AsyncSerialQueue> {
            let serialQueue = AsyncSerialQueue()
            await serialQueue.wait()
            return serialQueue
        }

        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(weakBox.isNil)
    }




}
