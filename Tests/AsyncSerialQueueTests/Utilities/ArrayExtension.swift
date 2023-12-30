//
//  ArrayExtension.swift
//  
//
//  Created by Danny Sung on 11/3/23.
//

import Foundation

extension Array where Element == Int {

    static func sequence(_ count: Int) -> [Int] {
        var array: [Int] = []

        for n in 0..<count {
            array.append(n)
        }

        return array
    }
}
