//
//  SocketThread.swift
//  TestClient
//
//  Created by Baby on 7/28/18.
//  Copyright © 2018 babyorg. All rights reserved.
//

import Cocoa

protocol SocketResultDelegate: class {
    func didReceiveError(error: Error)
    func didReceiveMessage( _ message: String)
}

final class SocketThread: Thread {

    private var socket: CFSocket!
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private let maxDataLength: Int
    private let host: String
    private var currentOffset: Int

    weak var delegate: SocketResultDelegate?

    init(hostAdress: String = "127.0.0.1", maxDataSize: Int = 1024) {
        host = hostAdress
        maxDataLength = maxDataSize
        currentOffset = 0
        super.init()
    }

    // MARK: - Public Methods

    func startClient() {
        do {
            try initializeClient()
        } catch let error {
            delegate?.didReceiveError(error: error)
            return
        }

        let socketLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0)

        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           socketLoopSource,
                           .defaultMode)

        CFRunLoopRun();
    }

    func stopClient() {
        guard socket != nil else { return }
        CFSocketInvalidate(self.socket);
        delegate?.didReceiveMessage("Socket disconnected...")
        CFRunLoopStop(CFRunLoopGetCurrent());
    }

    func sendMessage(_ message: String) {
        let dataBytes = [UInt8](message.data(using: .utf8)!)
        outputStream?.write(dataBytes, maxLength: dataBytes.count)
    }

    // MARK: - Private Methods

    private func initializeClient() throws {
        var context = CFSocketContext(version: 0,
                                      info: Unmanaged.passRetained(self).toOpaque(), // so we could access `self` context from pure method
                                      retain: nil,
                                      release: nil,
                                      copyDescription: nil)
        guard let clientSocket = CFSocketCreate(
            kCFAllocatorDefault,
            PF_INET,
            SOCK_STREAM,
            IPPROTO_TCP,
            CFSocketCallBackType.connectCallBack.rawValue,
            { (socket, callbackType, data, pointer, mutablePointer) in
                print("CallbackType: ", callbackType)
                guard let pointer = mutablePointer else { return }
                let mySelf = Unmanaged<SocketThread>.fromOpaque(pointer).takeUnretainedValue()
                switch callbackType {
                case .connectCallBack:

                    if data != nil {
                        mySelf.stopClient()
                    } else  {
                        let sockethandle = CFSocketGetNative(socket)
                        CFSocketSetSocketFlags(socket, 0)
                        CFSocketInvalidate(socket)
                        mySelf.socketConnected(withHandle: sockethandle)
                    }
                case .writeCallBack:
                    print("I am here")
                default:
                    break
                }
        },
            &context)
            else {
                throw NSError.describing("Failed to init socket")
        }

        var socketReuse = 1
        setsockopt(CFSocketGetNative(clientSocket),
                   SOL_SOCKET,
                   SO_REUSEPORT,
                   &socketReuse,
                   socklen_t(MemoryLayout<Int>.size))


        var sin = sockaddr_in()
        sin.sin_len = __uint8_t(MemoryLayout.size(ofValue: sin))
        sin.sin_family = sa_family_t(AF_INET)
        sin.sin_port = UInt16(3345).bigEndian
        inet_pton(AF_INET, host, &sin.sin_addr)

        let data = NSData(bytes: &sin, length: MemoryLayout<sockaddr_in>.size) as CFData
        let socketErr = CFSocketConnectToAddress(clientSocket, data, -1)

        switch socketErr {
        case .success:
            delegate?.didReceiveMessage("Connected to socket")
        case .error:
            throw NSError.describing("Failed to connet")
        case .timeout:
            throw NSError.describing("Connection timeout")
        }

        socket = clientSocket
    }

    private func socketConnected(withHandle socketHandle: CFSocketNativeHandle) {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, socketHandle, &readStream, &writeStream)

        let retainedReadStream = readStream!.takeRetainedValue()
        let retainedWriteStream = writeStream!.takeRetainedValue()

        CFReadStreamSetProperty(retainedReadStream, .socketNativeHandle, kCFBooleanTrue)
        CFWriteStreamSetProperty(retainedWriteStream, .socketNativeHandle, kCFBooleanTrue)

        inputStream = retainedReadStream as InputStream
        outputStream = retainedWriteStream as OutputStream

        inputStream?.delegate = self
        outputStream?.delegate = self

        inputStream?.schedule(in: .current, forMode: .defaultRunLoopMode)
        outputStream?.schedule(in: .current, forMode: .defaultRunLoopMode)

        inputStream?.open()
        outputStream?.open()
    }

    private func readReceivedData(fromStream inputStream: InputStream) {
        var buffer = [UInt8](repeating: 0, count: maxDataLength)
        let dataLength = inputStream.read(&buffer, maxLength: maxDataLength)

        if
            dataLength > 0,
            let message = NSString(bytes: buffer, length: dataLength, encoding: String.Encoding.utf8.rawValue) {
            delegate?.didReceiveMessage(message as String)
        } else if dataLength < 0 {
            let error = inputStream.streamError
            let outputError = NSError.describing(error?.localizedDescription ?? "Unknown error happened")
            delegate?.didReceiveError(error: outputError)
        }
    }
}

// MARK: - StreamDelegate

extension SocketThread: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            readReceivedData(fromStream: aStream as! InputStream)
        case .errorOccurred:
            let error = NSError.describing(aStream.streamError?.localizedDescription ?? "Unknown error")
            delegate?.didReceiveError(error: error)
        default:
            break
        }
    }
}
