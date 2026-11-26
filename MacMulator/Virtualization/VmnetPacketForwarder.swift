//
//  VmnetPacketForwarder.swift
//  MacMulator
//
//  Created by Vale on 25/11/26.
//

import Foundation
import vmnet

class VmnetIsolationGroup {
    private let lock = NSLock()
    private var macAddresses = Set<UInt64>()

    func insert(_ macAddress: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        macAddresses.insert(macAddress)
    }

    func remove(_ macAddress: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        macAddresses.remove(macAddress)
    }

    func contains(_ macAddress: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return macAddresses.contains(macAddress)
    }
}

@available(macOS 26.0, *)
class VmnetPacketForwarder {
    let virtualMachineFileHandle: FileHandle

    private static let PACKETS_PER_BATCH = 64
    private static let SOCKET_SEND_BUFFER_SIZE: Int32 = 1024 * 1024
    private static let SOCKET_RECEIVE_BUFFER_SIZE: Int32 = 4 * 1024 * 1024
    private static let START_TIMEOUT_SECONDS = 10.0
    private static let ETHERNET_HEADER_SIZE = 14

    private let queue: DispatchQueue
    private let interface: interface_ref
    private let hostSocket: Int32
    private let maxPacketSize: Int
    private let macAddress: UInt64
    private let isolationGroup: VmnetIsolationGroup
    private let fromVmnet: PacketBatch
    private let toVmnet: PacketBatch
    private var readSource: DispatchSourceRead?
    private var stopped = false

    init(network: vmnet_network_ref, networkName: String, macAddress: String, isolationGroup: VmnetIsolationGroup) throws {
        guard let parsedMacAddress = VmnetPacketForwarder.parseMacAddress(macAddress) else {
            throw VmnetNetworkError(networkName: networkName, status: .VMNET_INVALID_ARGUMENT)
        }

        var sockets: [Int32] = [-1, -1]
        guard socketpair(AF_UNIX, SOCK_DGRAM, 0, &sockets) == 0 else {
            throw VmnetNetworkError(networkName: networkName, status: .VMNET_FAILURE)
        }
        for socketDescriptor in sockets {
            var sendBufferSize = VmnetPacketForwarder.SOCKET_SEND_BUFFER_SIZE
            var receiveBufferSize = VmnetPacketForwarder.SOCKET_RECEIVE_BUFFER_SIZE
            setsockopt(socketDescriptor, SOL_SOCKET, SO_SNDBUF, &sendBufferSize, socklen_t(MemoryLayout<Int32>.size))
            setsockopt(socketDescriptor, SOL_SOCKET, SO_RCVBUF, &receiveBufferSize, socklen_t(MemoryLayout<Int32>.size))
        }
        _ = fcntl(sockets[0], F_SETFL, fcntl(sockets[0], F_GETFL) | O_NONBLOCK)

        let interfaceDescription = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_bool(interfaceDescription, vmnet_enable_isolation_key, true)
        // The VM keeps its own MAC address, which DHCP reservations and the guest IP lookup rely on
        xpc_dictionary_set_bool(interfaceDescription, vmnet_allocate_mac_address_key, false)

        let queue = DispatchQueue(label: "MacMulator.VmnetPacketForwarder")
        let started = DispatchSemaphore(value: 0)
        var startStatus: vmnet_return_t = .VMNET_FAILURE
        var maxPacketSize = 1514
        let startedInterface = vmnet_interface_start_with_network(network, interfaceDescription, queue) { status, parameters in
            startStatus = status
            if let parameters {
                maxPacketSize = Int(xpc_dictionary_get_uint64(parameters, vmnet_max_packet_size_key))
            }
            started.signal()
        }
        guard let startedInterface, started.wait(timeout: .now() + VmnetPacketForwarder.START_TIMEOUT_SECONDS) == .success, startStatus == .VMNET_SUCCESS else {
            if let startedInterface {
                vmnet_stop_interface(startedInterface, queue) { _ in }
            }
            close(sockets[0])
            close(sockets[1])
            throw VmnetNetworkError(networkName: networkName, status: startStatus)
        }

        self.queue = queue
        interface = startedInterface
        hostSocket = sockets[0]
        self.maxPacketSize = maxPacketSize
        self.macAddress = parsedMacAddress
        self.isolationGroup = isolationGroup
        fromVmnet = PacketBatch(count: VmnetPacketForwarder.PACKETS_PER_BATCH, packetSize: maxPacketSize)
        toVmnet = PacketBatch(count: VmnetPacketForwarder.PACKETS_PER_BATCH, packetSize: maxPacketSize)
        virtualMachineFileHandle = FileHandle(fileDescriptor: sockets[1], closeOnDealloc: true)

        isolationGroup.insert(parsedMacAddress)
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
            isolationGroup.remove(macAddress)
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

        for index in 0 ..< Int(count) where isAllowedFromNetwork(fromVmnet.buffers[index], size: fromVmnet.packets[index].vm_pkt_size) {
            // A full socket means the VM can't keep up: the packet is dropped, as on a congested link
            _ = send(hostSocket, fromVmnet.buffers[index], fromVmnet.packets[index].vm_pkt_size, 0)
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
        // Bound all datagrams examined, including those rejected by the filter.
        for _ in 0 ..< toVmnet.count {
            let size = recv(hostSocket, toVmnet.buffers[count], maxPacketSize, 0)
            guard size > 0 else { break }
            if isAllowedFromVirtualMachine(toVmnet.buffers[count], size: size) {
                toVmnet.setPacket(count, size: size)
                count += 1
            }
        }
        // The read source will fire again if datagrams remain.
        guard count > 0 else { return }
        var written = Int32(count)
        _ = vmnet_write(interface, toVmnet.packets, &written)
    }

    // vmnet doesn't apply its isolation key to these interfaces, so isolation is enforced here on the
    // Ethernet headers: a VM can only send with its own MAC address, and frames between VMs of the group are dropped
    private func isAllowedFromVirtualMachine(_ frame: UnsafeMutableRawPointer, size: Int) -> Bool {
        guard size >= VmnetPacketForwarder.ETHERNET_HEADER_SIZE else { return false }
        return VmnetPacketForwarder.macAddress(in: frame, at: 6) == macAddress && !isolationGroup.contains(VmnetPacketForwarder.macAddress(in: frame, at: 0))
    }

    private func isAllowedFromNetwork(_ frame: UnsafeMutableRawPointer, size: Int) -> Bool {
        guard size >= VmnetPacketForwarder.ETHERNET_HEADER_SIZE else { return false }
        return !isolationGroup.contains(VmnetPacketForwarder.macAddress(in: frame, at: 6))
    }

    private static func macAddress(in frame: UnsafeMutableRawPointer, at offset: Int) -> UInt64 {
        (0 ..< 6).reduce(UInt64(0)) { ($0 << 8) | UInt64(frame.load(fromByteOffset: offset + $1, as: UInt8.self)) }
    }

    private static func parseMacAddress(_ macAddress: String) -> UInt64? {
        let bytes = macAddress.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { return nil }
        return bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }
}

@available(macOS 26.0, *)
private class PacketBatch {
    let count: Int
    let packetSize: Int
    let buffers: [UnsafeMutableRawPointer]
    let vectors: UnsafeMutablePointer<iovec>
    let packets: UnsafeMutablePointer<vmpktdesc>

    init(count: Int, packetSize: Int) {
        self.count = count
        self.packetSize = packetSize
        buffers = (0 ..< count).map { _ in UnsafeMutableRawPointer.allocate(byteCount: packetSize, alignment: 16) }
        vectors = UnsafeMutablePointer<iovec>.allocate(capacity: count)
        packets = UnsafeMutablePointer<vmpktdesc>.allocate(capacity: count)
        reset()
    }

    deinit {
        buffers.forEach { $0.deallocate() }
        vectors.deallocate()
        packets.deallocate()
    }

    func reset() {
        for index in 0 ..< count {
            setPacket(index, size: packetSize)
        }
    }

    func setPacket(_ index: Int, size: Int) {
        vectors[index] = iovec(iov_base: buffers[index], iov_len: size)
        packets[index] = vmpktdesc(vm_pkt_size: size, vm_pkt_iov: vectors + index, vm_pkt_iovcnt: 1, vm_flags: 0)
    }
}
