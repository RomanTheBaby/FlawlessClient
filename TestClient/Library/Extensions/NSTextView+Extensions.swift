//
//  NSTextView+Extensions.swift
//  TestClient
//
//  Created by Baby on 7/29/18.
//  Copyright © 2018 babyorg. All rights reserved.
//

import Cocoa

extension NSTextView {
    func append(string: String) {
        self.textStorage?.append(NSAttributedString(string: string))
        self.scrollToEndOfDocument(nil)
    }
}
