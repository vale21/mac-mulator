//
//  QemuSerialConsole.swift
//  MacMulator
//

import Foundation

/// The serial console of a Qemu VM: a unix socket Qemu listens on (see QemuUtils.serialSocketPath), connected to directly
/// instead of through a pseudo-terminal running nc, whose line discipline cannot be set up in the App Store sandbox.
/// Qemu serves one client at a time: the connection is closed on detach().
class QemuSerialConsole: SerialConsole {
    private var socketDescriptor: Int32
    private var readSource: DispatchSourceRead?

    /// Connects to the socket, or returns nil if Qemu does not accept the connection
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

    /// Calls `handler` on the main thread with each output of the guest, until detach(). Qemu keeps no history, so the
    /// guest is sent a return to make it print its prompt
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
        if socketDescriptor >= 0 {
            close(socketDescriptor)
            socketDescriptor = -1
        }
    }

    func send(_ data: Data) {
        guard socketDescriptor >= 0 else { return }

        data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let written = write(socketDescriptor, buffer.baseAddress! + offset, buffer.count - offset)
                if written <= 0 {
                    break
                }
                offset += written
            }
        }
    }
}
