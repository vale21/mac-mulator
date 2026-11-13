//
//  SerialConsole.swift
//  MacMulator
//
//  Created by Vale on 03/11/2026.
//

import Foundation

protocol SerialConsole: AnyObject {
    func attach(_ handler: @escaping (Data) -> Void)
    func detach()
    func send(_ data: Data)
}

final class SerialPortReader {
    private let source: DispatchSourceRead

    init(fileHandle: FileHandle, onData: @escaping (Data) -> Void, onClose: @escaping () -> Void) {
        let descriptor = fileHandle.fileDescriptor
        source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: .main)
        source.setEventHandler { [source] in
            var buffer = [UInt8](repeating: 0, count: 4096)
            let count = read(descriptor, &buffer, buffer.count)
            if count > 0 {
                onData(Data(buffer[0 ..< count]))
            } else if count < 0, errno == EAGAIN || errno == EINTR {
                return
            } else {
                // The other end has closed the console (e.g. the VM has stopped)
                source.cancel()
                onClose()
            }
        }
        source.setCancelHandler {
            _ = fileHandle
        }
        source.resume()
    }

    func cancel() {
        source.cancel()
    }
}

final class SerialPortWriter {
    private static let maxPendingBytes = 256 * 1024

    private let descriptor: Int32
    private let source: DispatchSourceWrite
    private let lock = NSLock()
    private var pending = Data()
    private var suspended = true
    private var cancelled = false

    init?(fileHandle: FileHandle, label: String) {
        descriptor = fileHandle.fileDescriptor
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else { return nil }

        source = DispatchSource.makeWriteSource(fileDescriptor: descriptor, queue: DispatchQueue(label: label, qos: .utility))
        source.setEventHandler { [weak self] in
            self?.flush()
        }
        source.setCancelHandler {
            _ = fileHandle
        }
    }

    deinit {
        cancel()
    }

    func send(_ data: Data) {
        guard !data.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }
        guard !cancelled, data.count <= Self.maxPendingBytes - pending.count else { return }

        pending.append(data)
        if suspended {
            suspended = false
            source.resume()
        }
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        cancelLocked()
    }

    private func flush() {
        lock.lock()
        defer { lock.unlock() }

        while !pending.isEmpty {
            let count = min(pending.count, 4096)
            let written = pending.withUnsafeBytes { buffer in
                write(descriptor, buffer.baseAddress!, count)
            }
            if written > 0 {
                pending.removeFirst(written)
            } else if written < 0, errno == EINTR {
                continue
            } else if written < 0, errno == EAGAIN || errno == EWOULDBLOCK {
                return
            } else {
                cancelLocked()
                return
            }
        }

        if !cancelled, !suspended {
            suspended = true
            source.suspend()
        }
    }

    private func cancelLocked() {
        guard !cancelled else { return }
        cancelled = true
        pending.removeAll()
        source.cancel()
        // A suspended source never runs its cancel handler, so it must be resumed once
        if suspended {
            suspended = false
            source.resume()
        }
    }
}
