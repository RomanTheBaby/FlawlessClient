//
//  SocketThread.swift
//  TestClient
//
//  Created by Baby on 7/28/18.
//  Copyright © 2018 babyorg. All rights reserved.
//

import Cocoa

final class SocketThread: Thread {

    private var socket: CFSocket!
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var receivedData: [Data]
    private let maxDataLength: Int
    private var currentOffset: Int

    func acceptConnection(socket: CFSocket, type: CFSocketCallBackType, address: CFData, data: UnsafeRawPointer, info: UnsafeMutableRawPointer)
    {
        // Accept connection and stuff later
    }
    init(hostAdress: String = "127.0.0.1", maxDataSize: Int = 1024) throws {
        receivedData = []
        maxDataLength = maxDataSize
        currentOffset = 0
        super.init()
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
                throw NSError(domain: "com.baby", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to init socket"])
        }

//        var socketReuse = 1
//        setsockopt(CFSocketGetNative(clientSocket),
//                   SOL_SOCKET,
//                   SO_REUSEPORT,
//                   &socketReuse,
//                   socklen_t(MemoryLayout<Int>.size))

        var sin = sockaddr_in()
        sin.sin_len = __uint8_t(MemoryLayout.size(ofValue: sin))
        sin.sin_family = sa_family_t(AF_INET)
        sin.sin_port = UInt16(3345).bigEndian
//        sin.sin_addr.s_addr = inet_addr(hostAdress)
        inet_pton(AF_INET, hostAdress, &sin.sin_addr)

//        let data = CFDataCreate(kCFAllocatorDefault, sin, MemoryLayout<sockaddr_in>.size)
        let data = NSData(bytes: &sin, length: MemoryLayout<sockaddr_in>.size) as CFData
        let socketErr = CFSocketConnectToAddress(clientSocket, data, -1)

        switch socketErr {
        case .success:
            print("Connected to socket")
        case .error:
            throw NSError(domain: "com.baby", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to connet"])
        case .timeout:
            throw NSError(domain: "com.baby", code: 404, userInfo: [NSLocalizedDescriptionKey: "Connection timeout"])
        }

        socket = clientSocket
    }

    override func main() {
        super.main()

        let socketLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0)

        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           socketLoopSource,
                           .defaultMode)

        print("Run in loop")
        CFRunLoopRun();
    }

    private func stopClient() {
        CFSocketInvalidate(self.socket);
        CFRunLoopStop(CFRunLoopGetCurrent());
    }

    private func socketConnected(withHandle socketHandle: CFSocketNativeHandle) {
        //receivedData = []
        //currentOffset = 0

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

        if dataLength > 0 {
            let receivedMessage = NSString(bytes: buffer, length: dataLength, encoding: String.Encoding.utf8.rawValue)
            print("received message: ", receivedMessage)
//            let receivedData = Data(bytes: buffer, count: maxDataLength)
//            self.receivedData.insert(receivedData, at: 0)
        } else if dataLength < 0 {
            let error = inputStream.streamError
            print(error?.localizedDescription ?? "Unknown error happened")
        }
    }

    private func writeData(toStream outputStream: OutputStream) {
        guard !receivedData.isEmpty, let data = receivedData.last else { return }
        var dataBytes = [UInt8](data)
        dataBytes.append(UInt8(currentOffset))

        let length = data.count - currentOffset > maxDataLength ? maxDataLength : data.count - currentOffset
        let sentLength = outputStream.write(dataBytes, maxLength: length)

        if sentLength > 0 {
            currentOffset += sentLength

            if currentOffset == data.count {
                receivedData.removeLast()
                currentOffset = 0
            }
        } else if sentLength < 0 {
            let error = outputStream.streamError
            print(error?.localizedDescription ?? "Unknown Error")
        }
    }

//    private func acceptConnection(socket: CFSocket?, type: CFSocketCallBackType, address: CFData?, rawPointer: UnsafeRawPointer?, mutablePointer: UnsafeMutableRawPointer?) {
//        print("action type: ", type)
//
//        print(rawPointer)
//        print(mutablePointer)
//    }
    /*

     }*/
}

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
            print(aStream.streamError?.localizedDescription ?? "Unknown error")
        case .endEncountered:
            print("End")
        default:
            break
        }
    }
}
