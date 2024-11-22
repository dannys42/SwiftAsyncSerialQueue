//
//  TestConfiguration.swift
//  
//
//  Created by Danny Sung on 6/19/24.
//

import Foundation

actor TestConfiguration {
    static let shared = TestConfiguration()

    public func shouldRunAllTests() -> Bool {
        ProcessInfo.processInfo.environment["RUN_ALL_TESTS"] == "1"
    }
}
