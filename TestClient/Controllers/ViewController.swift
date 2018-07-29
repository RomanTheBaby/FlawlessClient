//
//  ViewController.swift
//  TestClient
//
//  Created by Baby on 7/22/18.
//  Copyright © 2018 babyorg. All rights reserved.
//

import Cocoa
import CoreFoundation

final class ViewController: NSViewController {

    private var clientSocket: SocketThread?

    @IBOutlet weak private var inputTextField: NSTextField!

    private var hasConnected = false

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
    }

    @IBAction func actionSendMessage(_ sender: NSTextField) {
        guard !sender.stringValue.isEmpty, let messageData = sender.stringValue.data(using: .utf8) else { return }

        if !hasConnected {
            connectedToServer()
        }

        guard clientSocket != nil else { return }

        clientSocket?.receivedData.insert(messageData, at: 0)

        let dataBytes = [UInt8]("".data(using: .utf8)!)
        clientSocket?.outputStream?.write(dataBytes, maxLength: 1)
    }

    private func connectedToServer() {
        do {
            clientSocket = try SocketThread()
            clientSocket?.start()
        } catch let error {
            print(error.localizedDescription)
        }
    }
}
