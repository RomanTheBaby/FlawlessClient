
//
//  NSViewController+Extension.swift
//  TestClient
//
//  Created by Baby on 7/24/18.
//  Copyright © 2018 babyorg. All rights reserved.
//

import Cocoa

extension NSViewController {
    func showAlert(for message: String, cancelTitle: String = "OK") {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: cancelTitle)
        alert.runModal()
    }

    func showAlert(for error: Error) {
        showAlert(for: error.localizedDescription)
    }
}
