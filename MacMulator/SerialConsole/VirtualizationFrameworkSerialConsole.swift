//
//  VirtualizationFrameworkSerialConsole.swift
//  MacMulator
//
//  Created by Vale on 30/10/2026.
//

import Foundation
import Virtualization

class VirtualizationFrameworkSerialConsole: SerialConsole {
    private static let maxBufferedBytes = 256 * 1024

    private let toGuest = Pipe()
    private let fromGuest = Pipe()
    private var reader: SerialPortReader?
    private let writer: SerialPortWriter?
    private var buffered = Data()
    private var outputHandler: ((Data) -> Void)?

    init() {
        writer = SerialPortWriter(fileHandle: toGuest.fileHandleForWriting, label: "VirtualizationFrameworkSerialConsole.write")
        // Guest output is read for the whole VM lifetime, so it can be replayed when a console is attached
        reader = SerialPortReader(fileHandle: fromGuest.fileHandleForReading, onData: { [weak self] data in
            self?.received(data)
        }, onClose: {})
    }

    deinit {
        reader?.cancel()
        writer?.cancel()
    }

    func makePortConfiguration() -> VZVirtioConsoleDeviceSerialPortConfiguration {
        let port = VZVirtioConsoleDeviceSerialPortConfiguration()
        port.attachment = VZFileHandleSerialPortAttachment(fileHandleForReading: toGuest.fileHandleForReading, fileHandleForWriting: fromGuest.fileHandleForWriting)
        return port
    }

    func attach(_ handler: @escaping (Data) -> Void) {
        if !buffered.isEmpty {
            handler(buffered)
        }
        outputHandler = handler
    }

    func detach() {
        outputHandler = nil
    }

    func send(_ data: Data) {
        writer?.send(data)
    }

    private func received(_ data: Data) {
        buffered.append(data)
        if buffered.count > Self.maxBufferedBytes {
            buffered.removeFirst(buffered.count - Self.maxBufferedBytes)
        }
        outputHandler?(data)
    }
}
