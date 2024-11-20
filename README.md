# SwiftAsyncSerialQueue

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdannys42%2FSwiftAsyncSerialQueue%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/dannys42/SwiftAsyncSerialQueue)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdannys42%2FSwiftAsyncSerialQueue%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/dannys42/SwiftAsyncSerialQueue)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)


AsyncSerialQueue is a simple library to provide [serial queue](https://www.avanderlee.com/swift/concurrent-serial-dispatchqueue/)-like capability using [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/).  Tasks placed in an AsyncSerialQueue are guaranteed to execute sequentially.

AsyncSerialQueue is currently only available on Apple platforms (i.e. not on Linux).  This is because of the need for locking and Swift [currently does not have a standard cross-platform locking mechnism](https://forums.swift.org/t/shared-mutable-state-sendable-and-locks/64336).


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

