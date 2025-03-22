# SwiftAsyncSerialQueue

[![APIDoc](https://img.shields.io/badge/docs-AsyncSerialQueue-1FBCE4.svg)](https://swiftpackageindex.com/dannys42/SwiftAsyncSerialQueue/main/documentation/asyncserialqueue)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdannys42%2FSwiftAsyncSerialQueue%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/dannys42/SwiftAsyncSerialQueue)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdannys42%2FSwiftAsyncSerialQueue%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/dannys42/SwiftAsyncSerialQueue)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)


`AsyncSerialQueue` is a library provides some useful patterns using Swift Concurrency:

`AsyncSerialQueue` is a class provides [serial queue](https://www.avanderlee.com/swift/concurrent-serial-dispatchqueue/)-like capability using [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/).  Tasks placed in an `AsyncSerialQueue` are guaranteed to execute sequentially.

`AsyncCoalescingQueue` is a companion class that has properties similar to [DispatchSource](https://www.mikeash.com/pyblog/friday-qa-2009-09-11-intro-to-grand-central-dispatch-part-iii-dispatch-sources.html).

AsyncSerialQueue is currently only available on Apple platforms (i.e. not on Linux).  This is because of the need for locking and Swift [currently does not have a standard cross-platform locking mechnism](https://forums.swift.org/t/shared-mutable-state-sendable-and-locks/64336).


# `AsyncSerialQueue`

## Example

### Simple Example
```swift
let serialQueue = AsyncSerialQueue()

func example() {
    serialQueue.async {
        print("1")
    }
    serialQueue.async {
        print("2")
    }
    serialQueue.async {
        print("3")
    }
    print("apple")
}
```

Note that `example()` does not need to be declared `async` here.

The numbers will always be output in order:
```
1
2
3
```
However, there is no guarantee where `apple` may appear:

```
apple
1
2
3
```
or

```
1
2
apple
3
```
or any other combination

### Waiting for the queue

There may be some cases (e.g. unit tests) where you need to wait for the serial queue to be empty.


```swift
func example() async {
    serialQueue.async {
        print("1")
    }

    await serialQueue.wait()

    serialQueue.async {
        print("2")
    }
}
```

`example()` will not complete return `1` is printed.  However, it could return before `2` is output.


### Mixing sync and async - Barrier Blocks

Similarly, if looking for something similar to [barrier blocks](https://developer.apple.com/documentation/dispatch/dispatch_barrier):

```swift
func example() async {
    serialQueue.async {
        print("1")
    }
    await serialQueue.sync {
        print("2")
    }
    serialQueue.async {
        print("3")
    }
    print("apple"")
}
```

In this case, `apple` will never appear before `2`.  And `example()` will not return until `2` is printed.


# `AsyncCoalescingQueue`

[Coalescing Queues](https://www.mikeash.com/pyblog/friday-qa-2009-09-11-intro-to-grand-central-dispatch-part-iii-dispatch-sources.html) can be a useful technique especially in flows where you only care about the first and last event, but would like to drop interim events if processing is still in play.  For example when processing user input, perhaps you want the first event in order to kick off processing and provide user immediate feedback, and you also want the last event because that represents the most up-to-date user state requested.  For example, consider a scrubber for an audio player.

In the GCD approach, coalescing queues acted on a trigger but could not take input very easily.  In this Swift implementation, the API is kept simply by relying on scoped variables at the point of call.  However, if there are multiple `.run()` blocks, make sure that it is acceptable for any of them to get dropped.  If multiple `.run()` blocks are required, consider placing the common code in a separate function that is called within the multiple `.run()` blocks.  Also consider whether multiple `AsyncCoalescingQueue()` instances or `AsyncSerialQueue()` may be a better fit.

`AsyncCoalescingQueue` is somewhat similar to `debounce` and `throttle` in Combine.  `debounce` has a fixed lag before the first event is emitted, requiring an additional `Concatenate` publisher if you do not wish to miss the first event.  `throttle` works on fixed time intervals, but may require tuning to balance the task with the speed of the hardware.  In some UI cases, you may wish to provide "best effort" responsiveness to the user.  `AsyncCoalescingQueue` (like GCD coalescing queues) will ensure responsiveness by automatically scaling to the workload and hardware it is running on.

## Example

The following code:

```swift
let coalescingQueue = AsyncCoalescingQueue()

coalescingQueue.run {
    try? await Task.sleep(for: .seconds(5))
    print("Run 1")
}
coalescingQueue.run {
    try? await Task.sleep(for: .seconds(5))
    print("Run 2")
}
coalescingQueue.run {
    try? await Task.sleep(for: .seconds(5))
    print("Run 3")
}
coalescingQueue.run {
    try? await Task.sleep(for: .seconds(5))
    print("Run 4")
}
coalescingQueue.run {
    try? await Task.sleep(for: .seconds(5))
    print("Run 5")
}
```
Will output the following:

```
Run 1
Run 5
```

And take 10 seconds to complete executing.


# Alternatives

Some related libraries:

* [swift-async-queue](https://github.com/dfed/swift-async-queue)
* [Queue](https://github.com/mattmassicotte/Queue)
* [Semaphore](https://github.com/groue/Semaphore)

# References
* [GCD: Coalescing Dispatch Queues](https://www.mikeash.com/pyblog/friday-qa-2009-09-11-intro-to-grand-central-dispatch-part-iii-dispatch-sources.html) 
* [Stack Overflow: Combine debounce and throttle ](https://stackoverflow.com/questions/60295544/how-do-you-apply-a-combine-operator-only-after-the-first-message-has-been-receiv)

