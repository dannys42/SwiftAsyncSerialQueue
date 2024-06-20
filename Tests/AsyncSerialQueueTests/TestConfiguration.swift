//
//  File.swift
//  
//
//  Created by Danny Sung on 6/19/24.
//

import Foundation

var shouldRunAllTest = {
    ProcessInfo.processInfo.environment["RUN_ALL_TESTS"] == "1"
}()

