//
//  VmnetNetwork.swift
//  MacMulator
//
//  Created by Vale on 18/11/26.
//

import Foundation

/// A vmnet logical network that one or more Apple VMs can join, so that they can see each other.
/// MacMulator provides three built-in networks (shared, host-only and isolated VM); the user can define more.
class VmnetNetwork: Codable {
    enum Mode: String, Codable {
        case hostOnly
        case shared
        /// Only used by the built-in "Isolated VM" network: every VM attached to it gets its own private
        /// host-only network, so it sees the host Mac only, and no other VM can see it.
        case isolated

        var localizedName: String {
            switch self {
            case .hostOnly:
                NSLocalizedString("VmnetNetwork.modeHostOnly", comment: "")
            case .shared:
                NSLocalizedString("VmnetNetwork.modeShared", comment: "")
            case .isolated:
                NSLocalizedString("VmnetNetwork.modeIsolated", comment: "")
            }
        }
    }

    static let HOST_ONLY_ID = "builtin.hostOnly"
    static let SHARED_ID = "builtin.shared"
    static let ISOLATED_ID = "builtin.isolated"
    /// The per-VM subnets of the Isolated VM network are picked automatically in this range, so user networks cannot use it.
    static let ISOLATED_SUBNETS_RANGE = "192.168.192.0/18"

    var id: String
    var name: String
    var mode: Mode
    /// IPv4 subnet in CIDR notation, e.g. 192.168.0.0/24. Empty for isolated networks, whose per-VM subnets are assigned automatically.
    var subnet: String
    var dhcpEnabled: Bool
    var natEnabled: Bool

    var isBuiltIn: Bool {
        [VmnetNetwork.SHARED_ID, VmnetNetwork.HOST_ONLY_ID, VmnetNetwork.ISOLATED_ID].contains(id)
    }

    /// The address range this network takes on the host Mac: its subnet, or the whole reserved range for isolated networks.
    var addressRange: String {
        mode == .isolated ? VmnetNetwork.ISOLATED_SUBNETS_RANGE : subnet
    }

    /// Port forwarding needs NAT between the host and the network, so it is only available on shared networks with NAT on.
    var supportsPortForwarding: Bool {
        mode == .shared && natEnabled
    }

    init(id: String = UUID().uuidString, name: String, mode: Mode, subnet: String, dhcpEnabled: Bool, natEnabled: Bool) {
        self.id = id
        self.name = name
        self.mode = mode
        self.subnet = subnet
        self.dhcpEnabled = dhcpEnabled
        self.natEnabled = natEnabled
    }

    static func builtInNetworks() -> [VmnetNetwork] {
        [
            VmnetNetwork(id: SHARED_ID, name: NSLocalizedString("VmnetNetwork.sharedName", comment: ""), mode: .shared, subnet: "192.168.129.0/24", dhcpEnabled: true, natEnabled: true),
            VmnetNetwork(id: HOST_ONLY_ID, name: NSLocalizedString("VmnetNetwork.hostOnlyName", comment: ""), mode: .hostOnly, subnet: "192.168.128.0/24", dhcpEnabled: true, natEnabled: false),
            VmnetNetwork(id: ISOLATED_ID, name: NSLocalizedString("VmnetNetwork.isolatedName", comment: ""), mode: .isolated, subnet: "", dhcpEnabled: true, natEnabled: false),
        ]
    }

    /// Built-in networks first, then the ones defined by the user.
    static func allNetworks() -> [VmnetNetwork] {
        builtInNetworks() + loadUserNetworks()
    }

    static func network(withId id: String?) -> VmnetNetwork? {
        allNetworks().first { $0.id == id }
    }

    /// Whether the string is an IPv4 network in CIDR notation, with a prefix length usable for
    /// a VM network (8 to 30 bits) and no host bits set in the address (192.168.0.0/24, not 192.168.0.1/24).
    static func isValidSubnet(_ cidr: String) -> Bool {
        guard let (address, prefixLength) = parseSubnet(cidr), (8 ... 30).contains(prefixLength) else {
            return false
        }
        return address & ~networkMask(prefixLength) == 0
    }

    /// Whether two subnets in CIDR notation share at least one address. The host Mac gets an address on
    /// every vmnet network, so networks with overlapping subnets would conflict on the host.
    static func subnetsOverlap(_ first: String, _ second: String) -> Bool {
        guard let (firstAddress, firstPrefix) = parseSubnet(first), let (secondAddress, secondPrefix) = parseSubnet(second) else {
            return false
        }
        // Two ranges overlap when they are equal on the prefix of the larger one
        let mask = networkMask(min(firstPrefix, secondPrefix))
        return firstAddress & mask == secondAddress & mask
    }

    static func loadUserNetworks() -> [VmnetNetwork] {
        guard let data = UserDefaults.standard.data(forKey: MacMulatorConstants.PREFERENCE_KEY_VMNET_NETWORKS) else {
            return []
        }
        return (try? PropertyListDecoder().decode([VmnetNetwork].self, from: data)) ?? []
    }

    static func saveUserNetworks(_ networks: [VmnetNetwork]) {
        if let data = try? PropertyListEncoder().encode(networks.filter { !$0.isBuiltIn }) {
            UserDefaults.standard.set(data, forKey: MacMulatorConstants.PREFERENCE_KEY_VMNET_NETWORKS)
        }
    }

    private static func parseSubnet(_ cidr: String) -> (address: UInt32, prefixLength: UInt32)? {
        guard CloudInitValidator.isValidCidr(cidr, ipv6: false) else {
            return nil
        }

        let parts = cidr.components(separatedBy: "/")
        guard let prefixLength = UInt32(parts[1]) else {
            return nil
        }

        var address = in_addr()
        inet_pton(AF_INET, parts[0], &address)
        return (UInt32(bigEndian: address.s_addr), prefixLength)
    }

    private static func networkMask(_ prefixLength: UInt32) -> UInt32 {
        prefixLength == 0 ? 0 : UInt32.max << (32 - prefixLength)
    }
}
