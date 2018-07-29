//
//  AloneChatViewController.swift
//  TestClient
//
//  Created by Baby on 7/29/18.
//  Copyright © 2018 babyorg. All rights reserved.
//

import Cocoa

class AloneChatViewController: NSViewController {

    private let viewModel = AloneChatViewModel()

    @IBOutlet weak private var logTextView: NSTextView!
    @IBOutlet weak private var inputTextField: NSTextField!
    @IBOutlet weak var disconnectButton: NSButton!
    @IBOutlet weak var connectButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
    }

    @IBAction func actionSendMessage(_ sender: NSTextField) {
        guard !sender.stringValue.isEmpty else { return }
        viewModel.sendMessage(sender.stringValue)
        sender.stringValue = ""
    }

    @IBAction func actionConnect(_ sender: NSButton) {
        viewModel.connectSocket()
    }

    @IBAction func actionDisconnect(_ sender: NSButton) {
        viewModel.stopClient()
    }
}

// MARK: - AloneChatViewModelDelegate

extension AloneChatViewController: AloneChatViewModelDelegate {
    func didReceiveError(error: Error) {
        showAlert(for: error)
    }

    func didReceiveMessage(_ message: String) {
        logTextView.append(string: message + "\n")
    }
}
