//
//  AloneChatViewModel.swift
//  TestClient
//
//  Created by Baby on 7/29/18.
//  Copyright © 2018 babyorg. All rights reserved.
//

import Cocoa

protocol AloneChatViewModelDelegate: class {
    func didReceiveError(error: Error)
    func didReceiveMessage(_ message: String) // well I could have used a custom model for message, but today I am too lazy for that :(
}

final class AloneChatViewModel {

    weak var delegate: AloneChatViewModelDelegate?

    private var socket: SocketThread?

    init() {

    }

    func sendMessage(_ message: String) {
        guard socket != nil else {
            delegate?.didReceiveError(error: NSError.describing("Server is no connected"))
            return
        }

        socket?.sendMessage(message)
    }

    func connectSocket() {

        if socket == nil {
            socket = SocketThread()
            socket?.start()
            socket?.delegate = self
        }

        stopClient()
        socket?.startClient()
    }

    func stopClient() {
        socket?.stopClient()
    }
}

// MARK: - SocketThreadDelegate

extension AloneChatViewModel: SocketResultDelegate {
    func didReceiveError(error: Error) {
        DispatchQueue.main.async {
            self.delegate?.didReceiveError(error: error)
        }
    }

    func didReceiveMessage(_ message: String) {
        DispatchQueue.main.async {
            self.delegate?.didReceiveMessage(message)
        }
    }
}
