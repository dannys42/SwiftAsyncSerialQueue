//
//  AsyncSerialQueue.swift
//
//
//  Created by Danny Sung on 11/3/23.
//

import Foundation
import os

/// ``AsyncSerialQueue`` provides behavior similar to serial `DispatchQueue`s while relying solely on Swift concurrency.
/// In other words, queued async blocks are guaranteed to execute in-order.
public class AsyncSerialQueue {
    public enum State {
        case setup
        case running
        case stopping
        case stopped
    }
    public typealias closure = @Sendable () async -> Void
    public var state: State {
        _state.withLock { $0 }
    }

    private var _state: OSAllocatedUnfairLock<State>
    private var taskStream: AsyncStream<closure>!
    private var continuation: AsyncStream<closure>.Continuation?
    private var executor: Task<(), Never>!

    private var cancelBlockList: BlockCollection

    public init() {
        self._state = .init(initialState: .setup)
        self.cancelBlockList = BlockCollection()

        self.taskStream = AsyncStream<closure>(bufferingPolicy: .unbounded) { continuation in
            self.continuation = continuation

            self._state.withLock { state in
                state = .running
            }
        }
        self.executor = Task {
            for await closure in self.taskStream {
                await closure()
            }

            self._state.withLock { state in
                state = .stopped
            }

            await self.cancelBlockList.execute()
        }
    }

    deinit {
        self.continuation!.finish()
    }
    
    /// Add a block to the queue
    /// - Parameter closure: Block to execute
    /// - Parameter completion: An optional completion handler will be executed after the `closure` is called.
    /// If the ``AsyncSerialQueue`` is cancelled, the `completion` will immediately execute and the `closure` will not be queued.
    public func async(_ closure: @escaping closure, completion: @escaping ()->Void = { }) {
        // TODO: Is it possible for continuation to not be ready here?
        guard !self.executor.isCancelled else {
            completion()
            return
        }

        self.continuation!.yield {
            await closure()
            completion()
        }
    }

    /// Cancel all queued blocks and prevent additional blocks from being queued.
    /// - Parameter newCompletion: An optional completion handler will be called after all blocks have been cancelled and finished executing.
    public func cancel(_ newCompletion: @Sendable @escaping ()->Void = { }) {
        self._state.withLock { state in
            state = .stopping
        }
        self.executor.cancel()
        self.continuation?.finish()
        if self.executor.isCancelled {
            newCompletion()
        } else {
            Task {
                await self.cancelBlockList.add(newCompletion)
            }
        }
    }

    /// Cancel all queued blocks and prevent additional blocks from being queued.
    /// This method will return after all blocks have been cancelled and finished executing.
    public func cancel() async {
        await withCheckedContinuation { continuation in
            self.cancel {
                continuation.resume()
            }
        }
        self.executor.cancel()
        self.continuation?.finish()
    }

    
    /// Queue a block, returning only after it has executed
    /// - Parameter closure: block to queue
    public func sync(_ closure: @escaping closure) async {
        await withCheckedContinuation { continuation in
            self.async {
                await closure()
            } completion: {
                continuation.resume()
            }
        }
    }
    
    /// Wait until all queued blocks have finished executing
    public func wait() async {
        await self.sync({})

        // If we were in the middle of cancelling, try to wait a bit until cancel has completed
        let maxIterations = 25
        var iteration = 0
        while self.state == .stopping && iteration < maxIterations {
            try? await Task.sleep(for: .microseconds(10))
            iteration += 1
        }
    }
}
