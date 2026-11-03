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
    private let writerQueue = DispatchQueue(label: "VirtualizationFrameworkSerialConsole.writer")
    private let writerLock = NSLock()
    private var writerSource: DispatchSourceWrite?
    private var pendingWrites = Data()
    private var writerCancelled = false
    /// Guest output received so far (accessed on the main thread)
    private var buffered = Data()
    private var outputHandler: ((Data) -> Void)?

    init() {
        fromGuest.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            DispatchQueue.main.async {
                self?.received(data)
            }
        }

        let writerDescriptor = toGuest.fileHandleForWriting.fileDescriptor
        let flags = fcntl(writerDescriptor, F_GETFL)
        if flags >= 0, fcntl(writerDescriptor, F_SETFL, flags | O_NONBLOCK) == 0 {
            let source = DispatchSource.makeWriteSource(fileDescriptor: writerDescriptor, queue: writerQueue)
            source.setEventHandler { [weak self] in
                self?.writePending()
            }
            source.resume()
            writerSource = source
        } else {
            writerCancelled = true
        }
    }

    deinit {
        fromGuest.fileHandleForReading.readabilityHandler = nil
        writerLock.lock()
        writerCancelled = true
        pendingWrites.removeAll()
        writerLock.unlock()
        writerSource?.cancel()
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
        writerLock.lock()
        pendingWrites.removeAll()
        writerLock.unlock()
    }

    func send(_ data: Data) {
        guard !data.isEmpty else { return }

        writerLock.lock()
        guard !writerCancelled, data.count <= Self.maxBufferedBytes - pendingWrites.count else {
            writerLock.unlock()
            return
        }
        pendingWrites.append(data)
        writerLock.unlock()

        writerQueue.async { [weak self] in
            self?.writePending()
        }
    }

    private func received(_ data: Data) {
        buffered.append(data)
        if buffered.count > Self.maxBufferedBytes {
            buffered.removeFirst(buffered.count - Self.maxBufferedBytes)
        }
        outputHandler?(data)
    }

    private func writePending() {
        writerLock.lock()
        defer { writerLock.unlock() }
        guard !writerCancelled, !pendingWrites.isEmpty else { return }

        while !pendingWrites.isEmpty {
            let count = min(pendingWrites.count, 4096)
            let written = pendingWrites.withUnsafeBytes { buffer in
                write(toGuest.fileHandleForWriting.fileDescriptor, buffer.baseAddress!, count)
            }
            if written > 0 {
                pendingWrites.removeFirst(written)
            } else if written < 0, errno == EINTR {
                continue
            } else if written < 0, errno == EAGAIN || errno == EWOULDBLOCK {
                return
            } else {
                pendingWrites.removeAll()
                writerCancelled = true
                writerSource?.cancel()
                return
            }
        }
    }
}
