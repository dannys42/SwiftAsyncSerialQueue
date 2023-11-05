//
//  DispatchGroupExtension.swift
//
//
//  Created by Danny Sung on 11/4/23.
//

import Foundation

extension DispatchGroup {
    func wait() async {
        await withCheckedContinuation { continuation in
            self.notify(queue: .main) {
                continuation.resume()
            }
        }
    }

}
