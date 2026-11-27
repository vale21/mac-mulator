//
//  GuestNetworkLookup.swift
//  MacMulator
//
//  Created by Vale on 30/10/2026.
//

import Foundation

/// The IPv4 address each VM sends from, as seen by MacMulator's packet forwarders (Qemu VMs on bridged and vmnet
/// networks, Apple VMs on isolated vmnet networks)
enum ObservedGuestAddresses {
    private static let lock = NSLock()
    private static var addresses: [UInt64: UInt32] = [:]

    static func observe(_ frame: UnsafeRawPointer, size: Int) {
        let etherType = size >= 14 ? UInt16(frame.load(fromByteOffset: 12, as: UInt8.self)) << 8 | UInt16(frame.load(fromByteOffset: 13, as: UInt8.self)) : 0
        // Source address of an IPv4 packet, sender address of an ARP message
        let addressOffset = switch etherType {
        case 0x0800 where size >= 34: 26
        case 0x0806 where size >= 42: 28
        default: -1
        }
        guard addressOffset >= 0 else { return }

        let address = (0 ..< 4).reduce(UInt32(0)) { ($0 << 8) | UInt32(frame.load(fromByteOffset: addressOffset + $1, as: UInt8.self)) }
        // 0.0.0.0 while asking for a DHCP lease, 169.254.x.x when there is none
        guard address != 0, address >> 16 != 0xA9FE else { return }

        let macAddress = (6 ..< 12).reduce(UInt64(0)) { ($0 << 8) | UInt64(frame.load(fromByteOffset: $1, as: UInt8.self)) }
        lock.lock()
        defer { lock.unlock() }
        addresses[macAddress] = address
    }

    static func forget(_ macAddress: String) {
        if let key = key(macAddress) {
            forget(key)
        }
    }

    static func forget(_ macAddress: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        addresses.removeValue(forKey: macAddress)
    }

    static func address(for macAddress: String) -> String? {
        guard let key = key(macAddress) else { return nil }
        lock.lock()
        let address = addresses[key]
        lock.unlock()
        return address.map { String(cString: inet_ntoa(in_addr(s_addr: $0.bigEndian))) }
    }

    private static func key(_ macAddress: String) -> UInt64? {
        let bytes = macAddress.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        return bytes.count == 6 ? bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) } : nil
    }
}

enum GuestNetworkLookup {
    private struct Lease {
        let ipAddress: String
        let leaseExpiry: UInt64
        /// Whether the lease is recorded under the MAC address of the guest
        let matchesMAC: Bool
    }

    private static let leasesPath = "/var/db/dhcpd_leases"
    // The DHCP reservations of the vmnet networks: their addresses never appear in the leases
    private static let reservationsPath = "/etc/bootptab"
    private static let maxCheckedLeases = 16
    private static let maxProbedHosts: UInt32 = 1024

    static func ipAddress(forMACAddress macAddress: String) -> String? {
        guard let mac = normalize(macAddress) else { return nil }
        // The ARP table reflects the guests that are up now. It is empty for a process that has no access to the local
        // network (e.g. launched from Xcode), so it cannot be the only source
        if let ipAddress = ipAddressFromARPTable(mac) {
            return ipAddress
        }

        // Addresses known to belong to this guest. Unlike ARP, they are also available without local network access
        var knownAddresses: [String] = []
        for ipAddress in [ObservedGuestAddresses.address(for: macAddress), reservedAddress(for: mac)].compactMap(\.self) + ownedLeaseAddresses(for: mac) where !knownAddresses.contains(ipAddress) {
            knownAddresses.append(ipAddress)
        }
        if let ipAddress = firstReachable(Array(knownAddresses.prefix(maxCheckedLeases))) {
            return ipAddress
        }

        // Probe lease addresses to populate ARP, but never treat SSH reachability as guest identity.
        let leases = dhcpLeases(for: mac)
        // Retry because the first connection may time out while resolving ARP.
        for _ in 0 ..< 2 {
            _ = firstReachable(leases.prefix(maxCheckedLeases).map(\.ipAddress))
            if let ipAddress = ipAddressFromARPTable(mac) {
                return ipAddress
            }
        }

        // The host has not talked to the guest yet: make it resolve every local address, then look again
        probeLocalSubnets()
        Thread.sleep(forTimeInterval: 1)
        // Nothing answers (e.g. the guest is still booting). The leases are no use then: they also list the addresses
        // the guest had in earlier boots, or before its system took over the network, and connecting there would hang
        return ipAddressFromARPTable(mac)
    }

    private static func firstReachable(_ ipAddresses: [String]) -> String? {
        var reachable = [Bool](repeating: false, count: ipAddresses.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: ipAddresses.count) { index in
            let isUp = isReachable(ipAddresses[index])
            lock.lock()
            reachable[index] = isUp
            lock.unlock()
        }
        return reachable.firstIndex(of: true).map { ipAddresses[$0] }
    }

    private static func normalize(_ macAddress: String) -> [UInt8]? {
        let bytes = macAddress.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        return bytes.count == 6 ? bytes : nil
    }

    /// Parses the leases file, made of blocks such as:
    ///   {
    ///       name=ubuntu
    ///       ip_address=192.168.64.3
    ///       hw_address=1,52:54:0:12:34:56
    ///       lease=0x6721f0a3
    ///   }
    /// and returns the leases, those of the guest first and the most recent first
    private static func dhcpLeases(for mac: [UInt8]) -> [Lease] {
        guard let contents = try? String(contentsOfFile: leasesPath, encoding: .utf8) else { return [] }

        var leases: [Lease] = []
        for block in contents.components(separatedBy: "}") {
            var fields: [String: String] = [:]
            for line in block.split(separator: "\n") {
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    fields[parts[0]] = parts[1]
                }
            }
            guard let ipAddress = fields["ip_address"] else { continue }

            // hw_address is "<hardware type>,<mac>"
            let hwAddress = fields["hw_address"]?.split(separator: ",").last
            let expiry = fields["lease"].flatMap { UInt64($0.replacingOccurrences(of: "0x", with: ""), radix: 16) } ?? 0
            leases.append(Lease(ipAddress: ipAddress, leaseExpiry: expiry, matchesMAC: hwAddress.flatMap { normalize(String($0)) } == mac))
        }
        return leases.sorted { ($0.matchesMAC ? 1 : 0, $0.leaseExpiry) > ($1.matchesMAC ? 1 : 0, $1.leaseExpiry) }
    }

    private static func reservedAddress(for mac: [UInt8]) -> String? {
        guard let contents = try? String(contentsOfFile: reservationsPath, encoding: .utf8) else { return nil }

        // "<name> <hardware type> <mac> <ip address>" lines, after a "%" line
        for line in contents.split(separator: "\n") {
            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            if fields.count >= 4, normalize(fields[2]) == mac {
                return fields[3]
            }
        }
        return nil
    }

    /// The lease addresses whose latest lease went to this guest: older leases of an address may have gone to another VM since
    private static func ownedLeaseAddresses(for mac: [UInt8]) -> [String] {
        var latestLeases: [String: Lease] = [:]
        for lease in dhcpLeases(for: mac) where lease.leaseExpiry >= latestLeases[lease.ipAddress]?.leaseExpiry ?? 0 {
            latestLeases[lease.ipAddress] = lease
        }
        return latestLeases.values.filter(\.matchesMAC).sorted { $0.leaseExpiry > $1.leaseExpiry }.map(\.ipAddress)
    }

    private static func isReachable(_ ipAddress: String) -> Bool {
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }
        posix_spawn_file_actions_addopen(&fileActions, 1, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&fileActions, 2, "/dev/null", O_WRONLY, 0)

        let arguments = ["nc", "-z", "-G", "2", ipAddress, "22"]
        let argv: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }

        var pid: pid_t = 0
        guard posix_spawn(&pid, "/usr/bin/nc", &fileActions, nil, argv, environ) == 0 else { return false }
        var status: Int32 = 0
        while waitpid(pid, &status, 0) < 0, errno == EINTR {}
        return status == 0
    }

    private static func ipAddressFromARPTable(_ mac: [UInt8]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        process.arguments = ["-an"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()

        for line in output.split(separator: "\n") {
            let words = line.split(separator: " ")
            guard words.count > 3, words[2] == "at", words[1].hasPrefix("("), words[1].hasSuffix(")"),
                  normalize(String(words[3])) == mac else { continue }
            return String(words[1].dropFirst().dropLast())
        }
        return nil
    }

    private static func probeLocalSubnets() {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return }
        defer { freeifaddrs(interfaces) }

        let udpSocket = socket(AF_INET, SOCK_DGRAM, 0)
        guard udpSocket >= 0 else { return }
        defer { close(udpSocket) }
        _ = fcntl(udpSocket, F_SETFL, fcntl(udpSocket, F_GETFL) | O_NONBLOCK)

        for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(interface.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let address = interface.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  let netmask = interface.pointee.ifa_netmask else { continue }

            let hostAddress = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            let mask = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            let hostCount = ~mask
            guard hostCount > 1, hostCount <= maxProbedHosts else { continue }

            let network = hostAddress & mask
            for host in 1 ..< hostCount where network | host != hostAddress {
                var destination = sockaddr_in()
                destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                destination.sin_family = sa_family_t(AF_INET)
                destination.sin_port = in_port_t(9).bigEndian // discard
                destination.sin_addr.s_addr = (network | host).bigEndian
                _ = withUnsafePointer(to: &destination) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(udpSocket, nil, 0, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
                }
            }
        }
    }
}
