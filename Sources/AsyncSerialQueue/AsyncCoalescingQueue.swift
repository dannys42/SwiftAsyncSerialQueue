//
//  File.swift
//  SwiftAsyncSerialQueue
//
//  Created by Danny Sung on 1/23/25.
//

import Foundation
import os

/// Provides behavior similar to DispatchSource using Swift Concurrency
public class AsyncCoalescingQueue: @unchecked Sendable {
    public let label: String?
    private let serialQueue: AsyncSerialQueue

    private let taskList = TaskList()
    private let priority: TaskPriority?

    public init(label: String? = nil, priority: TaskPriority? = nil) {
        self.label = label
        self.priority = priority
        self.serialQueue = AsyncSerialQueue(label: label, priority: priority)
    }
    
    /// Attempt to execute a given block.
    /// Will not attempt to execute more than 2 in-flight blocks.
    /// - Parameter block: block to execute
    public func run(_ block: @escaping () async -> Void) {
        self.serialQueue.async {
            let taskBox = TaskBox(block)
            await self.taskList.upsertTask(taskBox)

            self.triggerProcessNextTask()
        }
    }

    public func wait() async {
        await self.serialQueue.sync {
            while await self.taskList.isEmpty == false {
                await self.processNextTask()
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    private func triggerProcessNextTask() {
        Task(priority: self.priority) {
            await self.processNextTask()
        }
    }

    private func processNextTask() async {
        if await self.taskList.isAnyTaskRunning {
            return
        }

        guard let task = await self.taskList.firstTask else {
            return
        }

        switch task.state {
        case .running:
            break
        case .waiting:
            Task {
                await task.run()

                await self.processNextTask()
            }

        case .complete:
            await self.taskList.removeTask(task)
        }
    }
}

fileprivate actor TaskList: Sendable {
    private var tasks: [TaskBox] = []

    var isEmpty: Bool {
        self.tasks.isEmpty
    }

    var isAnyTaskRunning: Bool {
        for task in self.tasks {
            if task.state == .running {
                return true
            }
        }
        return false
    }

    var firstTask: TaskBox? {
        tasks.first
    }

    func upsertTask(_ task: TaskBox) {
        if self.tasks.count > 1 {
            if let lastTask = self.tasks.last {
                if lastTask.state != .running {
                    self.tasks.removeLast()
                }
            }
        }

        self.tasks.append(task)
    }

    func removeTask(_ task: TaskBox) {
        self.tasks.removeAll { $0 === task }
    }
}

fileprivate actor TaskBox: Sendable {
    enum State {
        case waiting
        case running
        case complete
    }

    nonisolated
    public private(set) var state: State {
        get {
            _state.withLock { $0 }
        }
        set {
            _state.withLock { $0 = newValue }
        }
    }
    nonisolated
    private let _state: OSAllocatedUnfairLock<State>

    private let block: () async -> Void

    init(_ block: @escaping () async -> Void) {
        self._state = .init(initialState: .waiting)

        self.block = block
    }

    func run() async {
        guard self.state == .waiting else {
            return
        }

        self.state = .running
        await self.block()
        self.state = .complete
    }
}
