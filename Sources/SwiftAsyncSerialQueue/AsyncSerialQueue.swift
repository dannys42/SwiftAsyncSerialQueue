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

    public func async(_ closure: @escaping closure) {
        self.async(closure, completion: { })
    }

    public func async(_ closure: @escaping closure, completion: @escaping ()->Void) {
        // TODO: Is it possible for continuation to not be ready here?
        guard !self.executor.isCancelled else {
            completion()
            return }

        self.continuation!.yield {
            await closure()
            completion()
        }
    }

    public func cancel(_ newCompletion: @Sendable @escaping ()->Void = { }) {
        self.executor.cancel()
        self.continuation?.finish()
        Task {
            await self.cancelBlockList.add(newCompletion)
        }
    }

    public func cancel() async {
        await withCheckedContinuation { continuation in
            self.cancel {
                continuation.resume()
            }
        }
    }


    public func sync(_ closure: @escaping closure) async {
        await withCheckedContinuation { continuation in
            self.async {
                await closure()
            } completion: {
                continuation.resume()
            }
        }
    }

    public func wait() async {
        await self.sync({})
    }
}
