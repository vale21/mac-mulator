//
//  QemuSerialConsole.swift
//  MacMulator
//

import Foundation

class QemuSerialConsole: SerialConsole {
    private let socketHandle: FileHandle
    private let writer: SerialPortWriter
    private var reader: SerialPortReader?

    init?(socketPath: String) {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return nil }
        // From here on the descriptor is closed when the last owner of the handle is released
        socketHandle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)

        var noSigPipe: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8CString)
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            for (index, byte) in pathBytes.enumerated() {
                buffer[index] = UInt8(bitPattern: byte)
            }
        }

        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0, let writer = SerialPortWriter(fileHandle: socketHandle, label: "QemuSerialConsole.write") else { return nil }
        self.writer = writer
    }

    deinit {
        detach()
    }

    func attach(_ handler: @escaping (Data) -> Void) {
        guard reader == nil else { return }
        reader = SerialPortReader(fileHandle: socketHandle, onData: handler, onClose: { [weak self] in
            self?.detach()
        })
        // Wake up the guest so that it prints a prompt
        send(Data([0x0D]))
    }

    func detach() {
        reader?.cancel()
        reader = nil
        writer.cancel()
        // Disconnect right away; the descriptor itself is closed once the sources release the handle
        shutdown(socketHandle.fileDescriptor, SHUT_RDWR)
    }

    func send(_ data: Data) {
        writer.send(data)
    }
}
