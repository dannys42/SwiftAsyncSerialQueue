//
//  Executor.swift
//  
//
//  Created by Danny Sung on 6/18/24.
//

import Foundation

class Executor: @unchecked Sendable {

    let taskPriority: TaskPriority?

    public typealias closure = @Sendable () async -> Void
    private var task: Task<Void, Never>!
    private var taskStream: AsyncStream<closure>!
    private var continuation: AsyncStream<closure>.Continuation?

    init(priority: TaskPriority?=nil, _ completion: @escaping () async -> Void = {}) {
        self.taskPriority = priority

        let taskStream = AsyncStream<closure>(bufferingPolicy: .unbounded) { continuation in
            self.continuation = continuation
        }
        self.taskStream = taskStream

        self.task = Task.detached(priority: priority) {
            for await closure in taskStream {
                await closure()

                if Task.isCancelled {
                    break
                }
            }

            await completion()
        }
    }


    func cancel() {
        self.task.cancel()
        self.continuation!.finish()
    }

    enum TaskState {
        case didQueue
        case didComplete
    }

    func async(_ closure: @escaping closure, block: @Sendable @escaping (TaskState, Task<Void,Never>) async -> Void = { _,_ in }) {
        self.continuation!.yield { [weak self] in
            guard let self else { return }

            let task = Task.detached(priority: self.taskPriority) {
                await closure()
            }

            await block(.didQueue, task)
            _ = await task.value
            await block(.didComplete, task)
        }
    }

}
