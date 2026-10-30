//
//  VirtualizationFrameworkSerialConsole.swift
//  MacMulator
//
//  Created by Vale on 30/10/2026.
//

import Foundation
import Virtualization

/// The serial console of a Linux Apple VM: a virtio console port (hvc0 in the guest) connected to two pipes.
/// The guest output is kept, up to a limit, so that a terminal opened later shows what was printed before it.
class VirtualizationFrameworkSerialConsole {
    private static let maxBufferedBytes = 256 * 1024

    private let toGuest = Pipe()
    private let fromGuest = Pipe()
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
    }

    deinit {
        fromGuest.fileHandleForReading.readabilityHandler = nil
    }

    /// The port to add to the configuration of the VM
    func makePortConfiguration() -> VZVirtioConsoleDeviceSerialPortConfiguration {
        let port = VZVirtioConsoleDeviceSerialPortConfiguration()
        port.attachment = VZFileHandleSerialPortAttachment(fileHandleForReading: toGuest.fileHandleForReading, fileHandleForWriting: fromGuest.fileHandleForWriting)
        return port
    }

    /// Calls `handler` on the main thread with everything the guest printed so far, then with each new output, until detach()
    func attach(_ handler: @escaping (Data) -> Void) {
        if !buffered.isEmpty {
            handler(buffered)
        }
        outputHandler = handler
    }

    func detach() {
        outputHandler = nil
    }

    /// Sends what is typed in the terminal to the guest
    func send(_ data: Data) {
        try? toGuest.fileHandleForWriting.write(contentsOf: data)
    }

    private func received(_ data: Data) {
        buffered.append(data)
        if buffered.count > Self.maxBufferedBytes {
            buffered.removeFirst(buffered.count - Self.maxBufferedBytes)
        }
        outputHandler?(data)
    }
}
