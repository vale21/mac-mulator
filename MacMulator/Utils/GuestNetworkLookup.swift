//
//  GuestNetworkLookup.swift
//  MacMulator
//
//  Created by Vale on 30/10/2026.
//

import Foundation

/// Finds the IP address of an Apple Virtualization VM from its MAC address, so that an SSH session can be opened on it.
/// NAT guests get their address from the macOS DHCP server, which records it in /var/db/dhcpd_leases (not readable
/// from the App Store sandbox); every guest also shows up in the ARP table of the host once they have exchanged traffic.
enum GuestNetworkLookup {
    private static let leasesPath = "/var/db/dhcpd_leases"
    /// Subnets larger than this are not probed (see probeLocalSubnets)
    private static let maxProbedHosts: UInt32 = 1024

    /// The IP address of the guest using `macAddress`, if it can be found. Blocks for about a second when the
    /// guest has to be probed: call it off the main thread.
    static func ipAddress(forMACAddress macAddress: String) -> String? {
        guard let mac = normalize(macAddress) else { return nil }
        if let ipAddress = ipAddressFromDHCPLeases(mac) ?? ipAddressFromARPTable(mac) {
            return ipAddress
        }
        // The host has not talked to the guest yet: make it resolve every local address, then look again
        probeLocalSubnets()
        Thread.sleep(forTimeInterval: 1)
        return ipAddressFromARPTable(mac)
    }

    /// The MAC address as six numbers: macOS writes the bytes without leading zeros (e.g. "a:1b:..."), the VM config with them
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
    /// and returns the address of the most recent lease of the guest
    private static func ipAddressFromDHCPLeases(_ mac: [UInt8]) -> String? {
        guard let contents = try? String(contentsOfFile: leasesPath, encoding: .utf8) else { return nil }

        var best: (ip: String, lease: UInt64)?
        for block in contents.components(separatedBy: "}") {
            var fields: [String: String] = [:]
            for line in block.split(separator: "\n") {
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    fields[parts[0]] = parts[1]
                }
            }
            // hw_address is "<hardware type>,<mac>"
            guard let ip = fields["ip_address"], let hwAddress = fields["hw_address"]?.split(separator: ",").last,
                  normalize(String(hwAddress)) == mac else { continue }

            let lease = fields["lease"].flatMap { UInt64($0.replacingOccurrences(of: "0x", with: ""), radix: 16) } ?? 0
            if best == nil || lease > best!.lease {
                best = (ip, lease)
            }
        }
        return best?.ip
    }

    /// Looks for the guest in the ARP table of the host, read with sysctl like `arp -an` does. Each entry is a route
    /// message followed by the IP address (sockaddr_in) and the link-level address (sockaddr_dl) it resolves to
    private static func ipAddressFromARPTable(_ mac: [UInt8]) -> String? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else { return nil }

        return buffer.withUnsafeBytes { raw -> String? in
            let dataOffset = MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data) ?? 8
            var offset = 0
            while offset + MemoryLayout<rt_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: rt_msghdr.self)
                let messageLength = Int(header.rtm_msglen)
                guard messageLength > 0 else { break }
                defer { offset += messageLength }

                let addressOffset = offset + MemoryLayout<rt_msghdr>.size
                guard addressOffset + MemoryLayout<sockaddr_in>.size <= length else { break }
                let address = raw.loadUnaligned(fromByteOffset: addressOffset, as: sockaddr_in.self)
                // Socket addresses are padded to 4 bytes (SA_SIZE in net/route.h)
                let addressLength = Int(address.sin_len)
                let linkOffset = addressOffset + (addressLength == 0 ? 4 : 1 + ((addressLength - 1) | 3))
                guard linkOffset + MemoryLayout<sockaddr_dl>.size <= length else { break }
                let link = raw.loadUnaligned(fromByteOffset: linkOffset, as: sockaddr_dl.self)
                guard link.sdl_alen == 6 else { continue }

                let macOffset = linkOffset + dataOffset + Int(link.sdl_nlen)
                guard macOffset + 6 <= length, Array(raw[macOffset ..< macOffset + 6]) == mac else { continue }

                var ipAddress = address.sin_addr
                var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                guard inet_ntop(AF_INET, &ipAddress, &text, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }
                return String(cString: text)
            }
            return nil
        }
    }

    /// Sends an empty UDP datagram to every address of the IPv4 subnets the host is on (the NAT bridge of the VMs and
    /// the LAN, for bridged VMs): resolving them puts every running guest in the ARP table
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
