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
    }
    
    public enum State: Sendable {
        case setup
        case running
        case stopping
        case stopped
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
    
    private var taskStream: AsyncStream<closure>!
    private var continuation: AsyncStream<closure>.Continuation?
    private var executor: Task<(), Never>!
    private var currentRunningTask: Task<(), Never>?
    
    private var cancelBlockList: BlockCollection
    private let taskPriority: TaskPriority?
    
    public init(priority: TaskPriority?=nil) {
        self._state = .init(initialState: .setup)
        self.cancelBlockList = BlockCollection()
        self.taskPriority = priority
        
        self.taskStream = AsyncStream<closure>(bufferingPolicy: .unbounded) { continuation in
            self.continuation = continuation
            
            self.state = .running
        }
        self.executor = self.createExecutor() {
            self.state = .stopped
        }
    }
    
    deinit {
        if self.state == .running {
            self.state = .stopping
        }
        self.executor.cancel()
        self.continuation!.finish()
    }
    
    /// Add a block to the queue
    /// - Parameter closure: Block to execute
    /// If the ``AsyncSerialQueue`` is cancelled, the `closure` will not be queued.
    public func async(_ closure: @escaping closure) {
        guard self.state == .running else {
            return
        }
        
//        // TODO: Is it possible for continuation to not be ready here?
//        guard !self.executor.isCancelled else {
//            return
//        }
//        
        self._async(closure)
    }
    
    /// Cancel all queued blocks and prevent additional blocks from being queued.
    /// - Parameter completion: An optional completion handler will be called after all blocks have been cancelled and finished executing.
    public func cancel(_ completion: @Sendable @escaping ()->Void = { }) {
        switch self.state {
        case .setup, .running:
            Task(priority: self.taskPriority) {
                await self.cancel()
                completion()
            }
        case .stopping:
            self._async {
                completion()
            }
        case .stopped:
            completion()
        }
        
        
        /*
        self.state = .stopping
        
        if self.executor.isCancelled {
            newCompletion()
        } else {
            Task(priority: self.taskPriority) {
                await self.cancelBlockList.add(newCompletion)
            }
        }
         */
    }
    
    /// Cancel all queued blocks and prevent additional blocks from being queued.
    /// This method will return after all blocks have been cancelled and finished executing.
    public func cancel() async {
        self.currentRunningTask?.cancel()
        
        guard self.state == .running else {
            return
        }
        
        self.state = .stopping
        await self._sync {
            self.state = .stopped
        }
//        self.executor.cancel()
//        self.continuation?.finish()
    }
    
    
    /// Queue a block, returning only after it has executed
    /// - Parameter closure: block to queue
    /// Note: If `AsyncSerialQueue` is cancelled, then `closure` is never executed.
    public func sync(_ closure: @escaping closure) async {
        guard self.state == .running else {
            return
        }
        
        await _sync(closure)
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
            print("  isCancelled: \(Task.isCancelled)  state: \(self.state)")
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
    
    // Enqueue regardless of state
    private func _async(_ closure: @escaping closure) {
        self.continuation!.yield {
            let task = Task {
                return await closure()
            }
            self.currentRunningTask = task
            
            _ = await task.value
        }
    }
    
    /// Queue a block, returning only after it has executed
    /// - Parameter closure: block to queue
    /// Note: If `AsyncSerialQueue` is cancelled, then `closure` is never executed.
    public func _sync(_ closure: @escaping closure) async {
        await withCheckedContinuation { continuation in
            self._async {
                await closure()
                continuation.resume()
            }
        }
    }


    private func createExecutor(_ completion: @escaping () async -> Void = {}) -> Task<(), Never> {
        return Task(priority: self.taskPriority) {
            for await closure in self.taskStream {
                await closure()
            }
            
            self.state = .stopped
            
            await self.cancelBlockList.execute()
            await completion()
        }
    }

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
