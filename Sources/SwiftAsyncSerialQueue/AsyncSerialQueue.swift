//
//  AsyncSerialQueue.swift
//
//
//  Created by Danny Sung on 11/3/23.
//

import Foundation
import os

public class AsyncSerialQueue {
    public enum State {
        case setup
        case running
        case stopped
    }
    public typealias closure = @Sendable () async -> Void
    public private(set) var state: OSAllocatedUnfairLock<State>

    private var taskStream: AsyncStream<closure>!
    private var continuation: AsyncStream<closure>.Continuation?
    private var executor: Task<(), Never>!

    public init() {
        self.state = .init(initialState: .setup)

        self.taskStream = AsyncStream<closure>(bufferingPolicy: .unbounded) { continuation in
            self.continuation = continuation

            self.state.withLock { state in
                state = .running
            }
        }
        self.executor = Task {
            for await closure in self.taskStream {
                await closure()
            }

            self.state.withLock { state in
                state = .stopped
            }
        }
    }

    deinit {
        self.continuation!.finish()
    }

    public func async(_ closure: @escaping closure) {
        // TODO: continuation may not be ready yet... we should fall back to storing the closures until the continuation is ready
        self.continuation!.yield {
            await closure()
        }
    }

    public func cancel() {
        self.executor.cancel()
    }


    public func sync(_ closure: @escaping closure) async {
        await withCheckedContinuation { continuation in
            self.async {
                await closure()
                continuation.resume()
            }
        }
    }

    public func wait() async {
        await self.sync({})
    }
}
