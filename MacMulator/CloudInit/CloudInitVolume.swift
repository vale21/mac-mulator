//
//  CloudInitVolume.swift
//  MacMulator
//
//  Created by Vale on 16/11/2026.
//

import CryptoKit
import Foundation
import Virtualization

/// The cloud-init NoCloud volume of a VM: an ISO image labelled "cidata", with the user-data, meta-data and
/// network-config files built from the provisioning information of the VM.
/// See https://docs.cloud-init.io/en/latest/reference/datasources/nocloud.html
enum CloudInitVolume {
    static let fileName = "cloud-init.iso"
    private static let volumeLabel = "cidata"
    // vmnet reserves addresses by MAC address: without this, systemd-networkd (Ubuntu Server) identifies
    // the VM by a DUID, gets a dynamic address and misses the reservation its port forwarding points to
    private static let dhcpIdentifier = "    dhcp-identifier: mac\n"

    static func path(for vm: VirtualMachine) -> String {
        vm.path + "/" + fileName
    }

    @discardableResult
    static func update(for vm: VirtualMachine) throws -> String? {
        let path = Self.path(for: vm)
        guard Utils.isCloudInitSupported(vm), let info = vm.provisioningInformation else {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
            return nil
        }

        // The network configuration matches the network card of the VM by its MAC address: it must not change between boots
        if vm.macAddress == nil {
            vm.macAddress = VZMACAddress.randomLocallyAdministered().string
            vm.writeToPlist()
        }

        let hostName = hostName(vm.displayName)
        let userData = userData(info, vmId: vm.id)
        let networkConfig = info.ipConfiguration.map { self.networkConfig($0, info, macAddress: vm.macAddress!) } ?? defaultNetworkConfig(macAddress: vm.macAddress!)

        // cloud-init applies the configuration once per instance: the id changes, and the configuration
        // is applied again on the next boot, only when the configuration changes.
        let contents = [hostName, userData, networkConfig].joined(separator: "\n")
        let hash = SHA256.hash(data: Data(contents.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        let metaData = "instance-id: \(quoted("iid-macmulator-" + hash))\nlocal-hostname: \(quoted(hostName))\n"

        let files: [(name: String, data: Data)] = [("meta-data", Data(metaData.utf8)), ("user-data", Data(userData.utf8)), ("network-config", Data(networkConfig.utf8))]
        try ISO9660Image.write(volumeIdentifier: volumeLabel, files: files, to: URL(fileURLWithPath: path))
        return path
    }

    private static func userData(_ info: ProvisioningInformation, vmId: String) -> String {
        // The salt is derived from the keychain id: the hash, and with it the instance id, is the same on every boot
        let salt = String(info.passwordKeychainId.filter { $0.isLetter || $0.isNumber }.prefix(16))
        var yaml = "#cloud-config\n"
        yaml += "users:\n"
        yaml += "  - name: \(quoted(info.userName))\n"
        yaml += "    gecos: \(quoted(info.userFullName))\n"
        yaml += "    shell: /bin/bash\n"
        yaml += "    sudo: \(quoted("ALL=(ALL) ALL"))\n"
        yaml += "    lock_passwd: false\n"
        yaml += "    hashed_passwd: \(quoted(SHA512Crypt.hash(info.userPassword, salt: salt)))\n"
        if !info.sshKeys.isEmpty {
            yaml += "    ssh_authorized_keys:\n"
            yaml += info.sshKeys.map { "      - \(quoted($0))\n" }.joined()
        }
        // Clones share the machine id of the original, which DHCP identifies the guest by: the VM id changes on clone
        yaml += "bootcmd:\n"
        yaml += "  - \(quoted(machineIdResetScript(vmId: vmId)))\n"
        if info.upgradePackages {
            yaml += "package_update: true\n"
            yaml += "package_upgrade: true\n"
        }
        return yaml
    }

    private static func machineIdResetScript(vmId: String) -> String {
        let marker = "/etc/macmulator-vm-id"
        var script = "if [ \"$(cat \(marker) 2>/dev/null)\" != \"\(vmId)\" ]; then "
        script += "rm -f /etc/machine-id /var/lib/dbus/machine-id; systemd-machine-id-setup; "
        script += "if [ -d /var/lib/dbus ]; then ln -sf /etc/machine-id /var/lib/dbus/machine-id; fi; "
        script += "echo \"\(vmId)\" > \(marker); fi"
        return script
    }

    private static func defaultNetworkConfig(macAddress: String) -> String {
        var yaml = "version: 2\n"
        yaml += "ethernets:\n"
        yaml += "  net0:\n"
        yaml += "    match:\n"
        yaml += "      macaddress: \(quoted(macAddress.lowercased()))\n"
        yaml += "    dhcp4: true\n"
        yaml += dhcpIdentifier
        return yaml
    }

    /// Network configuration version 2: https://docs.cloud-init.io/en/latest/reference/network-config-format-v2.html
    private static func networkConfig(_ ip: CloudInitIPConfiguration, _ info: ProvisioningInformation, macAddress: String) -> String {
        var yaml = "version: 2\n"
        yaml += "ethernets:\n"
        yaml += "  net0:\n"
        yaml += "    match:\n"
        yaml += "      macaddress: \(quoted(macAddress.lowercased()))\n"
        yaml += "    dhcp4: \(ip.ipv4Mode == .dhcp)\n"
        yaml += "    dhcp6: \(ip.ipv6Mode == .dhcp)\n"
        if ip.ipv4Mode == .dhcp {
            yaml += dhcpIdentifier
        }
        if ip.ipv6Mode == .slaac {
            yaml += "    accept-ra: true\n"
        } else if ip.ipv6Mode == .disabled {
            yaml += "    accept-ra: false\n"
            yaml += "    link-local: []\n"
        }

        var addresses: [String] = []
        var routes: [(to: String, via: String)] = []
        if ip.ipv4Mode == .staticAddress {
            addresses.append(ip.ipv4Cidr)
            if !ip.ipv4Gateway.isEmpty {
                routes.append(("0.0.0.0/0", ip.ipv4Gateway))
            }
        }
        if ip.ipv6Mode == .staticAddress {
            addresses.append(ip.ipv6Cidr)
            if !ip.ipv6Gateway.isEmpty {
                routes.append(("::/0", ip.ipv6Gateway))
            }
        }
        if !addresses.isEmpty {
            yaml += "    addresses:\n"
            yaml += addresses.map { "      - \(quoted($0))\n" }.joined()
        }
        if !routes.isEmpty {
            yaml += "    routes:\n"
            yaml += routes.map { "      - to: \(quoted($0.to))\n        via: \(quoted($0.via))\n" }.joined()
        }
        if !info.dnsServers.isEmpty || !info.dnsDomains.isEmpty {
            yaml += "    nameservers:\n"
            if !info.dnsServers.isEmpty {
                yaml += "      addresses:\n"
                yaml += info.dnsServers.map { "        - \(quoted($0))\n" }.joined()
            }
            if !info.dnsDomains.isEmpty {
                yaml += "      search:\n"
                yaml += info.dnsDomains.map { "        - \(quoted($0))\n" }.joined()
            }
        }
        return yaml
    }

    /// The VM name turned into a valid host name: lower case letters, digits and hyphens, at most 63 characters
    private static func hostName(_ name: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789")
        var result = String(name.lowercased().map { allowed.contains($0) ? $0 : "-" })
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        result = String(result.trimmingCharacters(in: CharacterSet(charactersIn: "-")).prefix(63))
        return result.isEmpty ? "macmulator-vm" : result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// A YAML double quoted string. A JSON string is a valid one, and JSONSerialization does the escaping.
    private static func quoted(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: string, options: [.fragmentsAllowed, .withoutEscapingSlashes]) else {
            return "\"\""
        }
        return String(decoding: data, as: UTF8.self)
    }
}
