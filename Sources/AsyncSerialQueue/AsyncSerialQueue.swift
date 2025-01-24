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
public final class AsyncSerialQueue: @unchecked Sendable {
    public enum Failures: Error {
        case queueIsCanceled
        case queueIsNotRunning
    }
    
    public enum State: Sendable {
        case setup
        case running
        case stopping
        case stopped

        var isRunning: Bool {
            self == .setup || self == .running
        }
    }
    public typealias closure = @Sendable () async -> Void
    public private(set) var state: State {
        get {
            _state.withLock { $0 }
        }
        set {
            _state.withLock { $0 = newValue }
        }
    }
    
    private var _state: OSAllocatedUnfairLock<State>
    
    private var _currentRunningTasks: OSAllocatedUnfairLock<Set<Task<(), Never>>>
    private var currentRunningTasks: Set<Task<(), Never>> {
        get {
            _currentRunningTasks.withLock { $0 }
        }
        set {
            _currentRunningTasks.withLock { $0 = newValue }
        }
    }

    private let taskPriority: TaskPriority?
    private let executor: Executor
    public let label: String?

    public init(label: String?=nil, priority: TaskPriority?=nil) {
        self.label = label
        self._state = .init(initialState: .setup)
        self._currentRunningTasks = .init(initialState: [])
        self.taskPriority = priority

        self.executor = Executor(priority: priority) {
            // completion
        }

        self.executor.async {
            self.state = .running
        }
    }
    
    deinit {
        if self.state == .running {
            self.state = .stopping
        }
        self.executor.cancel()
        self._currentRunningTasks.withLock({ tasks in
            tasks.forEach { task in
                task.cancel()
            }
        })
    }
    
    /// Add a block to the queue
    /// - Parameter closure: Block to execute
    /// If the ``AsyncSerialQueue`` is cancelled, the `closure` will not be queued.
    public func async(_ closure: @escaping closure) {
        guard self.state.isRunning else {
            return
        }
        
        self.executor.async {
            await closure()
        } block: { [weak self] state, task in
            guard let self else { return }

            switch state {
            case .didQueue:
                self.currentRunningTasks.insert(task)
            case .didComplete:
                self.currentRunningTasks.remove(task)
            }
        }
    }
    
    /// Cancel all queued blocks and prevent additional blocks from being queued.
    /// - Parameter completion: An optional completion handler will be called after all blocks have been cancelled and finished executing.
    public func cancel(_ completion: @Sendable @escaping ()->Void = { }) {
        switch self.state {
        case .setup, .running:
            self.state = .stopping
            // TODO: cancel running tasks here
            self.executor.async {
                self.state = .stopped
                completion()
            }
        case .stopping:
            self.executor.async {
                completion()
            }
        case .stopped:
            completion()
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
    }
    
    
    /// Queue a block, returning only after it has executed
    /// - Parameter closure: block to queue
    /// Note: If `AsyncSerialQueue` is cancelled, then `closure` is never executed.
    public func sync(_ closure: @escaping closure) async {
        guard self.state.isRunning else {
            return
        }

        await withCheckedContinuation { continuation in
            self.executor.async {
                await closure()

                continuation.resume()
            }
        }
    }

    /// Queue a block, returning only after it has executed
    /// - Parameter closure: block to queue
    /// Note: If `AsyncSerialQueue` is cancelled, then `closure` is never executed.
    /// - Returns: Result of closure
    /// - Throws: ``Failures/queueIsNotRunning`` if queue is not in a running state.
    public func sync<T>(_ closure: @escaping @Sendable () async throws -> T) async throws -> T {
        guard self.state.isRunning else {
            throw Failures.queueIsNotRunning
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.executor.async {
                do {
                    let result = try await closure()

                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }

            }
        }
    }

    /// Wait until all queued blocks have finished executing
    @discardableResult
    public func wait<C>(for duration: C.Instant.Duration?=nil, tolerance: C.Instant.Duration? = nil, clock: C = ContinuousClock()) async -> State where C : Clock {
        await self.sync({})
        
        let startTime = clock.now
        let delayDurations: BackoffValues<Int>
        
        if duration == nil {
            delayDurations = BackoffValues(1_000, 125_000, 250_000, 500_000)
        } else {
            delayDurations = BackoffValues(10, 25, 50, 100, 1_000, 10_000)
        }
        
        // If we were in the middle of cancelling, try to wait a bit until cancel has completed
        while (Task.isCancelled && self.state != .stopped) {
            try? await Task.sleep(for: .microseconds(delayDurations.next))

            if let duration {
                if startTime.duration(to: clock.now) > duration {
                    break
                }
            }
        }
        
        return self.state
    }
    
    #if false
    /// Restart a queue that was previously cancelled
    public func restart() async throws {
        guard self.executor.isCancelled else {
            throw Failures.queueIsCanceled
        }
        
        self.executor = self.createExecutor() {
            self.state = .stopped
        }
    }
    #endif
    
    // MARK: Private Methods
    
}


fileprivate actor BackoffValues<T> {
    private let values: [T]
    private var index: Int
    
    
    init(_ values: T...) {
        self.values = values
        self.index = 0
    }
    
    var next: T {
        let nextIndex: Int
        
        if (self.index+1) >= self.values.count {
            nextIndex = self.index
        } else {
            nextIndex = self.index+1
        }
        self.index = nextIndex
        
        return self.values[nextIndex]
    }
}
