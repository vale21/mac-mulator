//
//  VmnetBridgedForwarder.swift
//  MacMulator
//
//  Created by Vale on 27/11/26.
//

import Foundation
import vmnet

struct VmnetBridgeError: LocalizedError {
    let interfaceName: String
    let reason: String

    var errorDescription: String? {
        String(format: NSLocalizedString("VmnetBridgedForwarder.startFailed", comment: ""), interfaceName, reason)
    }
}

class VmnetBridgedForwarder {
    private static let PACKETS_PER_BATCH = 64
    private static let SOCKET_SEND_BUFFER_SIZE: Int32 = 1024 * 1024
    private static let SOCKET_RECEIVE_BUFFER_SIZE: Int32 = 4 * 1024 * 1024
    private static let START_TIMEOUT_SECONDS = 10.0

    private let queue: DispatchQueue
    private let interface: interface_ref
    private let hostSocket: Int32
    private let socketPaths: QemuSocketPaths
    private var qemuAddress: sockaddr_un
    private let maxPacketSize: Int
    private let fromVmnet: PacketBatch
    private let toVmnet: PacketBatch
    private var readSource: DispatchSourceRead?
    private var stopped = false

    // Qemu connects with "-netdev dgram": it binds its own path and sends one Ethernet frame per datagram to MacMulator's
    init(interfaceName: String, socketPaths: QemuSocketPaths) throws {
        let socketDescriptor: Int32
        do {
            socketDescriptor = try UnixDatagramSocket.bind(socketPaths.macMulator, removing: socketPaths.qemu)
        } catch {
            throw VmnetBridgeError(interfaceName: interfaceName, reason: error.localizedDescription)
        }
        var sendBufferSize = VmnetBridgedForwarder.SOCKET_SEND_BUFFER_SIZE
        var receiveBufferSize = VmnetBridgedForwarder.SOCKET_RECEIVE_BUFFER_SIZE
        setsockopt(socketDescriptor, SOL_SOCKET, SO_SNDBUF, &sendBufferSize, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(socketDescriptor, SOL_SOCKET, SO_RCVBUF, &receiveBufferSize, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(socketDescriptor, F_SETFL, fcntl(socketDescriptor, F_GETFL) | O_NONBLOCK)

        let interfaceDescription = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_uint64(interfaceDescription, vmnet_operation_mode_key, UInt64(operating_modes_t.VMNET_BRIDGED_MODE.rawValue))
        xpc_dictionary_set_string(interfaceDescription, vmnet_shared_interface_name_key, interfaceName)
        // The VM keeps its own MAC address, so that its DHCP lease survives restarts
        xpc_dictionary_set_bool(interfaceDescription, vmnet_allocate_mac_address_key, false)

        let queue = DispatchQueue(label: "MacMulator.VmnetBridgedForwarder")
        let started = DispatchSemaphore(value: 0)
        var startStatus: vmnet_return_t = .VMNET_FAILURE
        var maxPacketSize = 1514
        let startedInterface = vmnet_start_interface(interfaceDescription, queue) { status, parameters in
            startStatus = status
            if let parameters {
                maxPacketSize = Int(xpc_dictionary_get_uint64(parameters, vmnet_max_packet_size_key))
            }
            started.signal()
        }
        guard let startedInterface, started.wait(timeout: .now() + VmnetBridgedForwarder.START_TIMEOUT_SECONDS) == .success, startStatus == .VMNET_SUCCESS else {
            if let startedInterface {
                vmnet_stop_interface(startedInterface, queue) { _ in }
            }
            close(socketDescriptor)
            unlink(socketPaths.macMulator)
            throw VmnetBridgeError(interfaceName: interfaceName, reason: VmnetNetworkError.statusName(startStatus) + " (" + String(startStatus.rawValue) + ")")
        }

        self.queue = queue
        interface = startedInterface
        hostSocket = socketDescriptor
        self.socketPaths = socketPaths
        // Validated by the bind above
        qemuAddress = UnixDatagramSocket.socketAddress(socketPaths.qemu)!
        self.maxPacketSize = maxPacketSize
        fromVmnet = PacketBatch(count: VmnetBridgedForwarder.PACKETS_PER_BATCH, packetSize: maxPacketSize)
        toVmnet = PacketBatch(count: VmnetBridgedForwarder.PACKETS_PER_BATCH, packetSize: maxPacketSize)

        startForwarding()
    }

    func stop() {
        queue.sync {
            guard !stopped else { return }
            stopped = true
            vmnet_interface_set_event_callback(interface, .VMNET_INTERFACE_PACKETS_AVAILABLE, nil, nil)
            readSource?.cancel()
            readSource = nil
            vmnet_stop_interface(interface, queue) { _ in }
            unlink(socketPaths.macMulator)
            unlink(socketPaths.qemu)
        }
    }

    private func startForwarding() {
        vmnet_interface_set_event_callback(interface, .VMNET_INTERFACE_PACKETS_AVAILABLE, queue) { [weak self] _, _ in
            self?.forwardPacketsToVirtualMachine()
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: hostSocket, queue: queue)
        source.setEventHandler { [weak self] in
            self?.forwardPacketsToVmnet()
        }
        let socketToClose = hostSocket
        source.setCancelHandler {
            close(socketToClose)
        }
        readSource = source
        source.resume()
    }

    private func forwardPacketsToVirtualMachine() {
        guard !stopped else { return }
        fromVmnet.reset()
        var count = Int32(fromVmnet.count)
        guard vmnet_read(interface, fromVmnet.packets, &count) == .VMNET_SUCCESS, count > 0 else { return }

        for index in 0 ..< Int(count) {
            // Fails until Qemu has bound its socket, or when the VM can't keep up: the packet is dropped, as on a congested link
            UnixDatagramSocket.send(hostSocket, fromVmnet.buffers[index], fromVmnet.packets[index].vm_pkt_size, to: &qemuAddress)
        }
        if Int(count) == fromVmnet.count {
            queue.async { [weak self] in
                self?.forwardPacketsToVirtualMachine()
            }
        }
    }

    private func forwardPacketsToVmnet() {
        guard !stopped else { return }
        var count = 0
        while count < toVmnet.count {
            let size = recv(hostSocket, toVmnet.buffers[count], maxPacketSize, 0)
            guard size > 0 else { break }
            toVmnet.setPacket(count, size: size)
            count += 1
        }
        // The read source will fire again if datagrams remain.
        guard count > 0 else { return }
        var written = Int32(count)
        _ = vmnet_write(interface, toVmnet.packets, &written)
    }
}
