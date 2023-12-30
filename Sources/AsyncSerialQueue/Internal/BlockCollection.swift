//
//  BlockCollection.swift
//
//
//  Created by Danny Sung on 11/4/23.
//

import Foundation

/// Helper for maintaining cancel completion handlers
actor BlockCollection {
    typealias Block = @Sendable () async -> Void
    var blocks: [Block] = []

    func add(_ block: @escaping Block) {
        self.blocks.append(block)
    }

    func execute() {

        let executeBlocks = self.blocks
        self.blocks = []

        Task {
            for block in executeBlocks {
                await block()
            }
        }
    }

    deinit {
        let blocks = self.blocks
        if !blocks.isEmpty {
            Task {
                for block in blocks {
                    await block()
                }
            }
        }
    }

}
