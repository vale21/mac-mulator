//
//  QemuSerialConsole.swift
//  MacMulator
//

import Foundation

class QemuSerialConsole: SerialConsole {
    private static let maxPendingWriteBytes = 256 * 1024

    private var socketDescriptor: Int32
    private var readSource: DispatchSourceRead?
    private let writeStateLock = NSLock()
    private let writeQueue = DispatchQueue(label: "QemuSerialConsole.write", qos: .utility)
    private var pendingWriteData = Data()
    private var writerScheduled = false

    init?(socketPath: String) {
        socketDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else { return nil }

        var noSigPipe: Int32 = 1
        setsockopt(socketDescriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8CString)
        let maxLength = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count <= maxLength else {
            close(socketDescriptor)
            return nil
        }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            for (index, byte) in pathBytes.enumerated() {
                buffer[index] = UInt8(bitPattern: byte)
            }
        }

        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(socketDescriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0 else {
            close(socketDescriptor)
            return nil
        }
    }

    deinit {
        detach()
    }

    func attach(_ handler: @escaping (Data) -> Void) {
        guard socketDescriptor >= 0 else { return }

        let descriptor = socketDescriptor
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: .main)
        source.setEventHandler { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 4096)
            let count = read(descriptor, &buffer, buffer.count)
            if count > 0 {
                handler(Data(buffer[0 ..< count]))
            } else {
                // Qemu has closed the console (e.g. the VM has stopped)
                self?.detach()
            }
        }
        source.resume()
        readSource = source
        send(Data([0x0D]))
    }

    func detach() {
        readSource?.cancel()
        readSource = nil

        writeStateLock.lock()
        let descriptor = socketDescriptor
        socketDescriptor = -1
        pendingWriteData.removeAll()
        writeStateLock.unlock()

        guard descriptor >= 0 else { return }
        shutdown(descriptor, SHUT_RDWR)
        writeQueue.async {
            close(descriptor)
        }
    }

    func send(_ data: Data) {
        guard !data.isEmpty else { return }

        writeStateLock.lock()
        guard socketDescriptor >= 0 else {
            writeStateLock.unlock()
            return
        }

        let availableBytes = Self.maxPendingWriteBytes - pendingWriteData.count
        let bytesToAppend = min(data.count, availableBytes)
        guard bytesToAppend > 0 else {
            writeStateLock.unlock()
            return
        }

        pendingWriteData.append(contentsOf: data.prefix(bytesToAppend))
        let shouldScheduleWriter = !writerScheduled
        writerScheduled = true
        writeStateLock.unlock()

        if shouldScheduleWriter {
            writeQueue.async { [weak self] in
                self?.writePendingData()
            }
        }
    }

    private func writePendingData() {
        while true {
            writeStateLock.lock()
            guard socketDescriptor >= 0, !pendingWriteData.isEmpty else {
                writerScheduled = false
                writeStateLock.unlock()
                return
            }
            let descriptor = socketDescriptor
            let data = Data(pendingWriteData.prefix(4096))
            writeStateLock.unlock()

            let written = data.withUnsafeBytes { buffer in
                write(descriptor, buffer.baseAddress!, buffer.count)
            }
            if written < 0 && errno == EINTR {
                continue
            }
            guard written > 0 else {
                detach()
                return
            }

            writeStateLock.lock()
            if socketDescriptor == descriptor {
                pendingWriteData.removeFirst(min(written, pendingWriteData.count))
            }
            writeStateLock.unlock()
        }
    }
}
