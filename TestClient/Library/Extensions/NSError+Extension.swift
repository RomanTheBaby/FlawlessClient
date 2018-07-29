//
//  NSError+Extension.swift
//  TestClient
//
//  Created by Baby on 7/29/18.
//  Copyright © 2018 babyorg. All rights reserved.
//

import Cocoa

extension NSError {
    class func describing(_ description: String, code: Int = 404) -> Error {
        return NSError(domain: "com.baby", code: code, userInfo: [NSLocalizedDescriptionKey: description]) as Error
    }
}
