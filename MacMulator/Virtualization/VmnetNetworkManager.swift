//
//  VmnetNetworkManager.swift
//  MacMulator
//
//  Created by Vale on 19/11/26.
//

import Cocoa
import vmnet

struct VmnetNetworkError: LocalizedError {
    let networkName: String
    let status: vmnet_return_t

    var errorDescription: String? {
        String(format: NSLocalizedString("VmnetNetworkManager.creationFailed", comment: ""), networkName, VmnetNetworkError.statusName(status), Int(status.rawValue))
    }

    private static func statusName(_ status: vmnet_return_t) -> String {
        switch status {
        case .VMNET_FAILURE: "VMNET_FAILURE"
        case .VMNET_MEM_FAILURE: "VMNET_MEM_FAILURE"
        case .VMNET_INVALID_ARGUMENT: "VMNET_INVALID_ARGUMENT"
        case .VMNET_SETUP_INCOMPLETE: "VMNET_SETUP_INCOMPLETE"
        case .VMNET_INVALID_ACCESS: "VMNET_INVALID_ACCESS"
        case .VMNET_SHARING_SERVICE_BUSY: "VMNET_SHARING_SERVICE_BUSY"
        case .VMNET_NOT_AUTHORIZED: "VMNET_NOT_AUTHORIZED"
        default: "vmnet_return_t"
        }
    }
}

@available(macOS 26.0, *)
class VmnetNetworkManager {
    private struct ActiveNetwork {
        let network: vmnet_network_ref
        var users: Set<String>
    }

    static let shared = VmnetNetworkManager()

    private var activeNetworks: [String: ActiveNetwork] = [:]
    private var isolatedSubnets: [String: String] = [:]

    func acquireNetwork(for vm: VirtualMachine) throws {
        guard let network = VmnetNetwork.network(withId: vm.vmnetNetworkId ?? VmnetNetwork.SHARED_ID) ?? VmnetNetwork.network(withId: VmnetNetwork.SHARED_ID) else { return }

        let key = networkKey(for: vm, network: network)
        if var active = activeNetworks[key] {
            active.users.insert(vm.id)
            activeNetworks[key] = active
            return
        }

        let subnet = network.mode == .isolated ? try allocateIsolatedSubnet(for: vm, network: network) : network.subnet
        do {
            let created = try createNetwork(network, subnet: subnet)
            activeNetworks[key] = ActiveNetwork(network: created, users: [vm.id])
        } catch {
            isolatedSubnets.removeValue(forKey: vm.id)
            throw error
        }
    }

    func network(for vm: VirtualMachine) -> vmnet_network_ref? {
        activeNetworks.first { $0.value.users.contains(vm.id) }?.value.network
    }

    func releaseNetwork(for vm: VirtualMachine) {
        for (key, var active) in activeNetworks where active.users.contains(vm.id) {
            active.users.remove(vm.id)
            if active.users.isEmpty {
                activeNetworks.removeValue(forKey: key)
                Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(active.network)).release()
            } else {
                activeNetworks[key] = active
            }
        }
        isolatedSubnets.removeValue(forKey: vm.id)
    }

    private func networkKey(for vm: VirtualMachine, network: VmnetNetwork) -> String {
        // Every isolated VM gets its own private network
        network.mode == .isolated ? network.id + "." + vm.id : network.id
    }

    private func allocateIsolatedSubnet(for vm: VirtualMachine, network: VmnetNetwork) throws -> String {
        guard let (rangeAddress, rangePrefix) = VmnetNetwork.parseSubnet(MacMulatorConstants.VMNET_ISOLATED_SUBNETS_RANGE) else {
            throw VmnetNetworkError(networkName: network.name, status: .VMNET_INVALID_ARGUMENT)
        }

        let used = Set(isolatedSubnets.values)
        let count = UInt32(1) << (MacMulatorConstants.VMNET_ISOLATED_SUBNET_PREFIX_LENGTH - rangePrefix)
        for index in 0 ..< count {
            let address = rangeAddress + (index << (32 - MacMulatorConstants.VMNET_ISOLATED_SUBNET_PREFIX_LENGTH))
            let subnet = VmnetNetworkManager.addressString(address) + "/" + String(MacMulatorConstants.VMNET_ISOLATED_SUBNET_PREFIX_LENGTH)
            if !used.contains(subnet) {
                isolatedSubnets[vm.id] = subnet
                return subnet
            }
        }
        throw VmnetNetworkError(networkName: network.name, status: .VMNET_SHARING_SERVICE_BUSY)
    }

    private func createNetwork(_ network: VmnetNetwork, subnet: String) throws -> vmnet_network_ref {
        var status: vmnet_return_t = .VMNET_SUCCESS
        let mode: vmnet_mode_t = network.mode == .shared ? .VMNET_SHARED_MODE : .VMNET_HOST_MODE
        guard let configuration = vmnet_network_configuration_create(mode, &status) else {
            throw VmnetNetworkError(networkName: network.name, status: status)
        }
        defer { Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(configuration)).release() }

        guard let (subnetAddress, prefixLength) = VmnetNetwork.parseSubnet(subnet) else {
            throw VmnetNetworkError(networkName: network.name, status: .VMNET_INVALID_ARGUMENT)
        }
        // vmnet uses this address as the host gateway, and refuses to start DHCP when it is the network address
        var address = in_addr(s_addr: (subnetAddress + 1).bigEndian)
        var mask = in_addr(s_addr: VmnetNetwork.networkMask(prefixLength).bigEndian)
        try check(vmnet_network_configuration_set_ipv4_subnet(configuration, &address, &mask), network)

        if !network.dhcpEnabled {
            vmnet_network_configuration_disable_dhcp(configuration)
        }
        if network.mode == .shared, !network.natEnabled {
            vmnet_network_configuration_disable_nat44(configuration)
            vmnet_network_configuration_disable_nat66(configuration)
        }
        if network.supportsPortForwarding {
            try addPortForwarding(to: configuration, network: network, subnetAddress: subnetAddress, prefixLength: prefixLength)
        }

        guard let created = vmnet_network_create(configuration, &status) else {
            throw VmnetNetworkError(networkName: network.name, status: status)
        }
        return created
    }

    private func addPortForwarding(to configuration: vmnet_network_configuration_ref, network: VmnetNetwork, subnetAddress: UInt32, prefixLength: UInt32) throws {
        // Rules cannot be changed while the network is active, so they are set up at creation for every
        // VM attached to this network, each with a DHCP reservation to know the address to forward to.
        let attachedVMs = workspaceVMs()
            .filter { $0.networkDevice == QemuConstants.ATTACHMENT_VMNET && ($0.vmnetNetworkId ?? VmnetNetwork.SHARED_ID) == network.id && $0.macAddress != nil }
            .sorted { $0.id < $1.id }

        let lastHost = (UInt32(1) << (32 - prefixLength)) - 2
        var usedHostPorts = Set<Int32>()
        for (index, vm) in attachedVMs.enumerated() {
            let host = MacMulatorConstants.VMNET_FIRST_RESERVED_HOST + UInt32(index)
            guard host <= lastHost, let macAddress = vm.macAddress, let ethernetAddress = ether_aton(macAddress) else { continue }

            var reservedAddress = in_addr(s_addr: (subnetAddress + host).bigEndian)
            try check(vmnet_network_configuration_add_dhcp_reservation(configuration, ethernetAddress, &reservedAddress), network)

            for mapping in vm.portMappings ?? [] where !usedHostPorts.contains(mapping.hostPort) {
                usedHostPorts.insert(mapping.hostPort)
                try check(vmnet_network_configuration_add_port_forwarding_rule(configuration, UInt8(IPPROTO_TCP), sa_family_t(AF_INET), UInt16(truncatingIfNeeded: mapping.vmPort), UInt16(truncatingIfNeeded: mapping.hostPort), &reservedAddress), network)
            }
        }
    }

    private func workspaceVMs() -> [VirtualMachine] {
        (NSApp.delegate as? AppDelegate)?.rootController?.virtualMachines ?? []
    }

    private func check(_ status: vmnet_return_t, _ network: VmnetNetwork) throws {
        if status != .VMNET_SUCCESS {
            throw VmnetNetworkError(networkName: network.name, status: status)
        }
    }

    private static func addressString(_ address: UInt32) -> String {
        String(cString: inet_ntoa(in_addr(s_addr: address.bigEndian)))
    }
}
