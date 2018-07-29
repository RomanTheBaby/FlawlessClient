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
    private var dataToSend: [Data]
    private let maxDataLength: Int
    private let host: String
    private var currentOffset: Int

    weak var delegate: SocketResultDelegate?

    init(hostAdress: String = "127.0.0.1", maxDataSize: Int = 1024) {
        host = hostAdress
        dataToSend = []
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

        print("Run in loop")
        CFRunLoopRun();
    }

    func stopClient() {
        guard socket != nil else { return }
        CFSocketInvalidate(self.socket);
        CFRunLoopStop(CFRunLoopGetCurrent());
    }

    func sendMessage(_ message: String) {
        guard let messageData = message.data(using: .utf8) else { return }

//        dataToSend.insert(messageData, at: 0)

        let dataBytes = [UInt8](message.data(using: .utf8)!)
        outputStream?.write(dataBytes, maxLength: dataBytes.count)
    }

    // MARK: - Private Methods

    private func initializeClient() throws {
        var context = CFSocketContext(version: 0, info: Unmanaged.passRetained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        //{ 0, CFBridgingRetain(self), nil, nil, nil}
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
            print("Connected to socket")
        case .error:
            throw NSError.describing("Failed to connet")
        case .timeout:
            throw NSError.describing("Connection timeout")
        }

        socket = clientSocket
    }

    private func socketConnected(withHandle socketHandle: CFSocketNativeHandle) {
        dataToSend = []
        currentOffset = 0

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
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxDataLength)

        let dataLength = inputStream.read(buffer, maxLength: maxDataLength)

        if
            dataLength > 0,
            let receivedMessage = String(bytesNoCopy: buffer, length: dataLength, encoding: .utf8, freeWhenDone: true) {
            delegate?.didReceiveMessage(receivedMessage)
        } else if dataLength < 0 {
            let error = inputStream.streamError
            let outputError = NSError.describing(error?.localizedDescription ?? "Unknown error happened")
            delegate?.didReceiveError(error: outputError)
        }
    }

    private func writeData(toStream outputStream: OutputStream) {
        guard !dataToSend.isEmpty, let data = dataToSend.last else { return }
        var dataBytes = [UInt8](data)
        dataBytes.append(UInt8(currentOffset))

        let length = data.count - currentOffset > maxDataLength ? maxDataLength : data.count - currentOffset
        let sentLength = outputStream.write(dataBytes, maxLength: length)

        if sentLength > 0 {
            currentOffset += sentLength

            if currentOffset == data.count {
                dataToSend.removeLast()
                currentOffset = 0
            }
        } else if sentLength < 0 {
            let error = outputStream.streamError
            let outputError = NSError.describing(error?.localizedDescription ?? "Unknown error happened")
            delegate?.didReceiveError(error: outputError)        }
    }
}

// MARK: - StreamDelegate

extension SocketThread: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasSpaceAvailable:
            writeData(toStream: aStream as! OutputStream)
        case .hasBytesAvailable:
            readReceivedData(fromStream: aStream as! InputStream)
        case .openCompleted:
            print("Did open stream")
        case .errorOccurred:
            let error = NSError.describing(aStream.streamError?.localizedDescription ?? "Unknown error")
            delegate?.didReceiveError(error: error)
        case .endEncountered:
            print("End")
        default:
            break
        }
    }
}
