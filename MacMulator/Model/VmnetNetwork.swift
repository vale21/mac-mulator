//
//  VmnetNetwork.swift
//  MacMulator
//
//  Created by Vale on 18/11/26.
//

import Foundation

class VmnetNetwork: Codable {
    enum Mode: String, Codable {
        case hostOnly
        case shared
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

    var id: String
    var name: String
    var mode: Mode
    var subnet: String
    var dhcpEnabled: Bool
    var natEnabled: Bool

    var isBuiltIn: Bool {
        [VmnetNetwork.SHARED_ID, VmnetNetwork.HOST_ONLY_ID, VmnetNetwork.ISOLATED_ID].contains(id)
    }

    var addressRange: String {
        mode == .isolated ? MacMulatorConstants.VMNET_ISOLATED_SUBNETS_RANGE : subnet
    }

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
            VmnetNetwork(id: SHARED_ID, name: NSLocalizedString("VmnetNetwork.sharedName", comment: ""), mode: .shared, subnet: MacMulatorConstants.VMNET_SHARED_SUBNET, dhcpEnabled: true, natEnabled: true),
            VmnetNetwork(id: HOST_ONLY_ID, name: NSLocalizedString("VmnetNetwork.hostOnlyName", comment: ""), mode: .hostOnly, subnet: MacMulatorConstants.VMNET_HOST_ONLY_SUBNET, dhcpEnabled: true, natEnabled: false),
            VmnetNetwork(id: ISOLATED_ID, name: NSLocalizedString("VmnetNetwork.isolatedName", comment: ""), mode: .isolated, subnet: "", dhcpEnabled: true, natEnabled: false),
        ]
    }

    static func allNetworks() -> [VmnetNetwork] {
        builtInNetworks() + loadUserNetworks()
    }

    static func network(withId id: String?) -> VmnetNetwork? {
        allNetworks().first { $0.id == id }
    }

    static func isValidSubnet(_ cidr: String) -> Bool {
        guard let (address, prefixLength) = parseSubnet(cidr), MacMulatorConstants.VMNET_SUBNET_PREFIX_LENGTHS.contains(prefixLength) else {
            return false
        }
        return address & ~networkMask(prefixLength) == 0
    }

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
