#if false
//
//  SimpleLock.swift
//
//
//  Created by Danny Sung on 6/5/24.
//

import Foundation
import os

protocol SimpleLockInterface: Sendable {
    associatedtype Value
    
    init(initialState: Value)
    
    func withLockUnchecked<R>(_ body: (inout Value) throws -> R) rethrows -> R
    
    func withLock<R>(_ body: @Sendable (inout Value) throws -> R) rethrows -> R where R : Sendable
}

@propertyWrapper
struct SimpleLock<Value: Sendable>: SimpleLockInterface {
    var wrappedValue: Value {
        get {
            self.withLock({ $0 })
        }
        set {
            self.withLock({ $0 = newValue })
        }
    }
    
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
    private var unfairLock: SimpleUnfairLock<Value>!
        
    private var semaphoreLock: SimpleLockSemaphore<Value>!

    init(initialState: Value) {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *) {
            self.unfairLock = SimpleUnfairLock(initialState: initialState)
            self.semaphoreLock = nil
        } else {
            self.semaphoreLock = nil
            self.semaphoreLock = SimpleLockSemaphore(initialState: initialState)
        }
    }
    
    func withLockUnchecked<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *) {
            return try self.unfairLock.withLockUnchecked(body)
        } else {
            return try self.semaphoreLock.withLockUnchecked(body)
        }
    }
    
    func withLock<R>(_ body: @Sendable (inout Value) throws -> R) rethrows -> R where R : Sendable {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *) {
            return try unfairLock.withLock(body)
        } else {
            return try self.semaphoreLock.withLock(body)
        }
    }
    

}


@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
final class SimpleUnfairLock<V: Sendable>: @unchecked Sendable, SimpleLockInterface {

    private var unfairLock: OSAllocatedUnfairLock<V>
    
    init(initialState: V) {
        self.unfairLock = .init(initialState: initialState)
    }
    
    func withLockUnchecked<R>(_ body: (inout V) throws -> R) rethrows -> R {
        return try self.unfairLock.withLockUnchecked(body)
    }
    
    func withLock<R>(_ body: @Sendable (inout V) throws -> R) rethrows -> R where R : Sendable {
        return try self.unfairLock.withLock(body)
    }
    

}

final class SimpleLockSemaphore<V>: @unchecked Sendable, SimpleLockInterface {
    private let semaphore: DispatchSemaphore
    private var value: V

    
    init(initialState: V) {
        self.value = initialState
        self.semaphore = DispatchSemaphore(value: 1)
    }

    public func withLockUnchecked<R>(_ body: (inout V) throws -> R) rethrows -> R {
        self.semaphore.wait()
        defer { self.semaphore.signal() }
        
        return try body(&self.value)
    }
    
    func withLock<R>(_ body: @Sendable (inout V) throws -> R) rethrows -> R where R : Sendable {
        return try self.withLockUnchecked(body)
    }
}

#endif
