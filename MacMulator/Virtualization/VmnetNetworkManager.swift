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

    static func statusName(_ status: vmnet_return_t) -> String {
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

struct VmnetUnsupportedError: LocalizedError {
    let virtualMachineName: String

    var errorDescription: String? {
        String(format: NSLocalizedString("VirtualizationFrameworkVirtualMachineRunner.vmnetUnsupported", comment: ""), virtualMachineName)
    }
}

struct VmnetSubnetConflictError: LocalizedError {
    let networkName: String
    let subnet: String
    let interface: String
    let interfaceSubnet: String

    var errorDescription: String? {
        String(format: NSLocalizedString("VmnetNetworkManager.subnetConflict", comment: ""), networkName, subnet, interface, interfaceSubnet)
    }
}

struct VmnetReservationCapacityError: LocalizedError {
    let networkName: String
    let capacity: Int
    let required: Int

    var errorDescription: String? {
        String(format: NSLocalizedString("VmnetNetworkManager.reservationCapacityExceeded", comment: ""), networkName, required, capacity)
    }
}

struct VmnetInvalidPortMappingError: LocalizedError {
    let virtualMachineName: String
    let mappingName: String
    let port: Int32

    var errorDescription: String? {
        String(format: NSLocalizedString("VmnetNetworkManager.invalidPortMapping", comment: ""), virtualMachineName, mappingName, Int(port))
    }
}

@available(macOS 26.0, *)
class VmnetNetworkManager {
    private struct ActiveNetwork {
        let network: vmnet_network_ref
        let gatewayAddress: UInt32
        // Taken when the network is created: VMs joining later use it even if the saved settings changed since
        let isolationGroup: VmnetIsolationGroup?
        // MAC address and mappings of each VM whose port forwarding was set up when the network was created
        let portForwarding: [String: String]?
        var users: Set<String>
    }

    static let shared = VmnetNetworkManager()

    private var activeNetworks: [String: ActiveNetwork] = [:]
    private var isolatedSubnets: [String: String] = [:]
    private var forwarders: [String: VmnetPacketForwarder] = [:]

    func acquireNetwork(for vm: VirtualMachine) throws {
        guard let network = VmnetNetwork.effectiveNetwork(withId: vm.vmnetNetworkId) else { return }

        let key = networkKey(for: vm, network: network)
        if var active = activeNetworks[key] {
            active.users.insert(vm.id)
            activeNetworks[key] = active
            try startForwarderIfNeeded(for: vm, networkName: network.name, active: active)
            return
        }

        let subnet = network.mode == .isolated ? try allocateIsolatedSubnet(for: vm, network: network) : network.subnet
        if let conflict = Utils.hostInterfaceSubnets().first(where: { VmnetNetwork.subnetsOverlap(subnet, $0.subnet) }) {
            isolatedSubnets.removeValue(forKey: vm.id)
            throw VmnetSubnetConflictError(networkName: network.name, subnet: subnet, interface: conflict.interface, interfaceSubnet: conflict.subnet)
        }
        do {
            let (created, portForwarding) = try createNetwork(network, subnet: subnet, startingVM: vm)
            activeNetworks[key] = ActiveNetwork(network: created, gatewayAddress: (VmnetNetwork.parseSubnet(subnet)?.address ?? 0) + 1, isolationGroup: network.isVMIsolationEnabled ? VmnetIsolationGroup() : nil, portForwarding: portForwarding, users: [vm.id])
        } catch {
            isolatedSubnets.removeValue(forKey: vm.id)
            throw error
        }
        if let active = activeNetworks[key] {
            try startForwarderIfNeeded(for: vm, networkName: network.name, active: active)
        }
    }

    func virtualMachinesBlockingPortMappings(of vm: VirtualMachine) -> (networkName: String, runningVirtualMachines: [String])? {
        guard let network = VmnetNetwork.effectiveNetwork(withId: vm.vmnetNetworkId), let active = activeNetworks[networkKey(for: vm, network: network)],
              let portForwarding = active.portForwarding, portForwarding[vm.id] != VmnetNetworkManager.portForwardingSignature(of: vm) else { return nil }

        let runningVirtualMachines = Utils.workspaceVirtualMachines().filter { active.users.contains($0.id) && $0.id != vm.id }.map(\.displayName)
        return runningVirtualMachines.isEmpty ? nil : (network.name, runningVirtualMachines)
    }

    func isolatedFileHandle(for vm: VirtualMachine) -> FileHandle? {
        forwarders[vm.id]?.virtualMachineFileHandle
    }

    func network(for vm: VirtualMachine) -> vmnet_network_ref? {
        activeNetworks.first { $0.value.users.contains(vm.id) }?.value.network
    }

    func runningVirtualMachineIds(on network: VmnetNetwork) -> Set<String> {
        activeNetworks
            .filter { $0.key == network.id || $0.key.hasPrefix(network.id + ".") }
            .reduce(into: Set<String>()) { $0.formUnion($1.value.users) }
    }

    func gatewayAddresses() -> Set<UInt32> {
        Set(activeNetworks.values.map(\.gatewayAddress))
    }

    func releaseNetwork(for vm: VirtualMachine) {
        forwarders.removeValue(forKey: vm.id)?.stop()
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

    private func startForwarderIfNeeded(for vm: VirtualMachine, networkName: String, active: ActiveNetwork) throws {
        // Apple VMs attach to the network directly unless it isolates its VMs; Qemu VMs always go through a forwarder
        guard active.isolationGroup != nil || vm.isQemuVirtualMachine, forwarders[vm.id] == nil else { return }

        do {
            let qemuSocketPaths = vm.isQemuVirtualMachine ? QemuUtils.networkSocketPaths(forVMAt: vm.path) : nil
            forwarders[vm.id] = try VmnetPacketForwarder(network: active.network, networkName: networkName, macAddress: vm.macAddress ?? "", isolationGroup: active.isolationGroup, qemuSocketPaths: qemuSocketPaths)
        } catch {
            releaseNetwork(for: vm)
            throw error
        }
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
        let hostSubnets = Utils.hostInterfaceSubnets(excludingAddresses: gatewayAddresses()).map(\.subnet)
        let count = UInt32(1) << (MacMulatorConstants.VMNET_ISOLATED_SUBNET_PREFIX_LENGTH - rangePrefix)
        for index in 0 ..< count {
            let address = rangeAddress + (index << (32 - MacMulatorConstants.VMNET_ISOLATED_SUBNET_PREFIX_LENGTH))
            let subnet = VmnetNetworkManager.addressString(address) + "/" + String(MacMulatorConstants.VMNET_ISOLATED_SUBNET_PREFIX_LENGTH)
            if !used.contains(subnet), !hostSubnets.contains(where: { VmnetNetwork.subnetsOverlap(subnet, $0) }) {
                isolatedSubnets[vm.id] = subnet
                return subnet
            }
        }
        throw VmnetNetworkError(networkName: network.name, status: .VMNET_SHARING_SERVICE_BUSY)
    }

    private func createNetwork(_ network: VmnetNetwork, subnet: String, startingVM: VirtualMachine) throws -> (network: vmnet_network_ref, portForwarding: [String: String]?) {
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
        var portForwarding: [String: String]?
        if network.supportsPortForwarding {
            portForwarding = try addPortForwarding(to: configuration, network: network, subnetAddress: subnetAddress, prefixLength: prefixLength, startingVM: startingVM)
        }

        guard let created = vmnet_network_create(configuration, &status) else {
            throw VmnetNetworkError(networkName: network.name, status: status)
        }
        return (created, portForwarding)
    }

    private func addPortForwarding(to configuration: vmnet_network_configuration_ref, network: VmnetNetwork, subnetAddress: UInt32, prefixLength: UInt32, startingVM: VirtualMachine) throws -> [String: String] {
        // Rules cannot be changed while the network is active, so they are set up at creation for every
        // VM attached to this network, each with a DHCP reservation to know the address to forward to.
        let networks = VmnetNetwork.allNetworks()
        let attachedVMs = Utils.workspaceVirtualMachines()
            .filter { $0.usesVmnetNetwork && !($0.portMappings ?? []).isEmpty && VmnetNetwork.effectiveNetwork(withId: $0.vmnetNetworkId, in: networks)?.id == network.id }
            .filter { $0.macAddress.flatMap { ether_aton($0) } != nil }
            .sorted { $0.id < $1.id }

        // .0 is the network, .1 the host gateway and the last address the broadcast one. Small subnets have no room
        // left for dynamic DHCP addresses below the usual first reserved host, so they reserve from the first guest address
        let lastHost = (UInt32(1) << (32 - prefixLength)) - 2
        let firstHost = lastHost >= MacMulatorConstants.VMNET_FIRST_RESERVED_HOST * 2 ? MacMulatorConstants.VMNET_FIRST_RESERVED_HOST : 2
        let capacity = Int(lastHost - firstHost + 1)
        guard attachedVMs.count <= capacity else {
            throw VmnetReservationCapacityError(networkName: network.name, capacity: capacity, required: attachedVMs.count)
        }

        // Addresses follow the VM order, so they don't depend on which VM starts the network. When two VMs map the
        // same host port, the VM being started gets it: the other one is stopped and can't receive the traffic anyway.
        let hosts = Dictionary(uniqueKeysWithValues: attachedVMs.enumerated().map { ($1.id, firstHost + UInt32($0)) })
        let rulesOrder = attachedVMs.filter { $0.id == startingVM.id } + attachedVMs.filter { $0.id != startingVM.id }

        var usedHostPorts = Set<Int32>()
        var portForwarding: [String: String] = [:]
        for vm in rulesOrder {
            guard let macAddress = vm.macAddress, let ethernetAddress = ether_aton(macAddress), let host = hosts[vm.id] else { continue }

            var reservedAddress = in_addr(s_addr: (subnetAddress + host).bigEndian)
            try check(vmnet_network_configuration_add_dhcp_reservation(configuration, ethernetAddress, &reservedAddress), network)

            var installedMappings: [PortMapping] = []
            for mapping in vm.portMappings ?? [] where !usedHostPorts.contains(mapping.hostPort) {
                // vmnet takes 16-bit ports: an out-of-range value would silently become another port
                if let invalidPort = [mapping.vmPort, mapping.hostPort].first(where: { !MacMulatorConstants.VALID_PORTS.contains($0) }) {
                    if vm.id == startingVM.id {
                        throw VmnetInvalidPortMappingError(virtualMachineName: vm.displayName, mappingName: mapping.name, port: invalidPort)
                    }
                    continue
                }
                usedHostPorts.insert(mapping.hostPort)
                try check(vmnet_network_configuration_add_port_forwarding_rule(configuration, UInt8(IPPROTO_TCP), sa_family_t(AF_INET), UInt16(truncatingIfNeeded: mapping.vmPort), UInt16(truncatingIfNeeded: mapping.hostPort), &reservedAddress), network)
                installedMappings.append(mapping)
            }
            // Only what was installed: a VM that lost a host port to another one is told so when it joins
            portForwarding[vm.id] = VmnetNetworkManager.portForwardingSignature(macAddress: macAddress, mappings: installedMappings)
        }
        return portForwarding
    }

    private static func portForwardingSignature(of vm: VirtualMachine) -> String? {
        guard vm.isNetworkEnabled else { return nil }
        return portForwardingSignature(macAddress: vm.macAddress ?? "", mappings: vm.portMappings ?? [])
    }

    private static func portForwardingSignature(macAddress: String, mappings: [PortMapping]) -> String? {
        guard !mappings.isEmpty else { return nil }
        return macAddress + "|" + mappings.map { "\($0.vmPort):\($0.hostPort)" }.sorted().joined(separator: ",")
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
