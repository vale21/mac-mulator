//
//  ISO9660Image.swift
//  MacMulator
//
//  Created by Vale on 16/11/2026.
//

import Foundation

/// Writes a minimal ISO 9660 image with a Joliet extension, holding some small files in its root directory.
/// Joliet keeps the file names as they are (e.g. cloud-init "user-data"), where plain ISO 9660 only allows 8.3 upper case names.
enum ISO9660Image {
    private static let sectorSize = 2048
    // Sectors 0-15 are the system area, then: primary descriptor, Joliet descriptor, terminator,
    // the 4 path tables, the 2 root directories. The file contents follow.
    private static let primaryDescriptorSector = 16
    private static let jolietDescriptorSector = 17
    private static let terminatorSector = 18
    private static let primaryLPathTableSector = 19
    private static let primaryMPathTableSector = 20
    private static let jolietLPathTableSector = 21
    private static let jolietMPathTableSector = 22
    private static let primaryRootSector = 23
    private static let jolietRootSector = 24
    private static let firstFileSector = 25
    private static let pathTableSize = 10

    private struct Entry {
        let name: String
        let data: Data
        let sector: Int
    }

    static func write(volumeIdentifier: String, files: [(name: String, data: Data)], to url: URL) throws {
        var entries: [Entry] = []
        var sector = firstFileSector
        for file in files.sorted(by: { $0.name < $1.name }) {
            entries.append(Entry(name: file.name, data: file.data, sector: sector))
            sector += sectorCount(file.data.count)
        }
        let totalSectors = sector
        let date = Date()

        var image = Data(count: totalSectors * sectorSize)
        put(&image, at: primaryDescriptorSector, volumeDescriptor(joliet: false, volumeIdentifier: volumeIdentifier, totalSectors: totalSectors, date: date))
        put(&image, at: jolietDescriptorSector, volumeDescriptor(joliet: true, volumeIdentifier: volumeIdentifier, totalSectors: totalSectors, date: date))
        var terminator = Data([255] + Array("CD001".utf8) + [1])
        terminator.count = sectorSize
        put(&image, at: terminatorSector, terminator)
        put(&image, at: primaryLPathTableSector, pathTable(rootSector: primaryRootSector, bigEndian: false))
        put(&image, at: primaryMPathTableSector, pathTable(rootSector: primaryRootSector, bigEndian: true))
        put(&image, at: jolietLPathTableSector, pathTable(rootSector: jolietRootSector, bigEndian: false))
        put(&image, at: jolietMPathTableSector, pathTable(rootSector: jolietRootSector, bigEndian: true))
        put(&image, at: primaryRootSector, rootDirectory(entries, joliet: false, date: date))
        put(&image, at: jolietRootSector, rootDirectory(entries, joliet: true, date: date))
        for entry in entries {
            put(&image, at: entry.sector, entry.data)
        }
        try image.write(to: url, options: .atomic)
    }

    private static func sectorCount(_ size: Int) -> Int {
        (size + sectorSize - 1) / sectorSize
    }

    private static func put(_ image: inout Data, at sector: Int, _ data: Data) {
        let start = sector * sectorSize
        image.replaceSubrange(start ..< start + data.count, with: data)
    }

    private static func volumeDescriptor(joliet: Bool, volumeIdentifier: String, totalSectors: Int, date: Date) -> Data {
        var d = Data(count: sectorSize)
        d[0] = joliet ? 2 : 1
        d.replaceSubrange(1 ..< 6, with: Array("CD001".utf8))
        d[6] = 1
        d.replaceSubrange(8 ..< 40, with: text("", length: 32, joliet: joliet))
        d.replaceSubrange(40 ..< 72, with: text(volumeIdentifier, length: 32, joliet: joliet))
        d.replaceSubrange(80 ..< 88, with: bothEndian32(totalSectors))
        if joliet {
            // UCS-2 level 3
            d.replaceSubrange(88 ..< 91, with: [0x25, 0x2F, 0x45])
        }
        d.replaceSubrange(120 ..< 124, with: bothEndian16(1))
        d.replaceSubrange(124 ..< 128, with: bothEndian16(1))
        d.replaceSubrange(128 ..< 132, with: bothEndian16(sectorSize))
        d.replaceSubrange(132 ..< 140, with: bothEndian32(pathTableSize))
        d.replaceSubrange(140 ..< 144, with: littleEndian32(joliet ? jolietLPathTableSector : primaryLPathTableSector))
        d.replaceSubrange(148 ..< 152, with: bigEndian32(joliet ? jolietMPathTableSector : primaryMPathTableSector))
        d.replaceSubrange(156 ..< 190, with: directoryRecord(name: [0], sector: joliet ? jolietRootSector : primaryRootSector, size: sectorSize, isDirectory: true, date: date))
        d.replaceSubrange(190 ..< 318, with: text("", length: 128, joliet: joliet))
        d.replaceSubrange(318 ..< 446, with: text("", length: 128, joliet: joliet))
        d.replaceSubrange(446 ..< 574, with: text("", length: 128, joliet: joliet))
        d.replaceSubrange(574 ..< 702, with: text("MACMULATOR", length: 128, joliet: joliet))
        d.replaceSubrange(702 ..< 813, with: text("", length: 111, joliet: joliet))
        d.replaceSubrange(813 ..< 830, with: descriptorDate(date))
        d.replaceSubrange(830 ..< 847, with: descriptorDate(date))
        d.replaceSubrange(847 ..< 864, with: Array("0000000000000000".utf8) + [0])
        d.replaceSubrange(864 ..< 881, with: Array("0000000000000000".utf8) + [0])
        d[881] = 1
        return d
    }

    private static func pathTable(rootSector: Int, bigEndian: Bool) -> Data {
        var d = Data([1, 0])
        d.append(contentsOf: bigEndian ? bigEndian32(rootSector) : littleEndian32(rootSector))
        d.append(contentsOf: bigEndian ? [0, 1] : [1, 0])
        d.append(contentsOf: [0, 0])
        return d
    }

    private static func rootDirectory(_ entries: [Entry], joliet: Bool, date: Date) -> Data {
        let rootSector = joliet ? jolietRootSector : primaryRootSector
        var d = Data()
        d.append(directoryRecord(name: [0], sector: rootSector, size: sectorSize, isDirectory: true, date: date))
        d.append(directoryRecord(name: [1], sector: rootSector, size: sectorSize, isDirectory: true, date: date))
        for entry in entries {
            let name = joliet ? jolietName(entry.name) : primaryName(entry.name)
            d.append(directoryRecord(name: name, sector: entry.sector, size: entry.data.count, isDirectory: false, date: date))
        }
        return d
    }

    private static func directoryRecord(name: [UInt8], sector: Int, size: Int, isDirectory: Bool, date: Date) -> Data {
        let length = 33 + name.count + (name.count % 2 == 0 ? 1 : 0)
        var d = Data(count: length)
        d[0] = UInt8(length)
        d.replaceSubrange(2 ..< 10, with: bothEndian32(sector))
        d.replaceSubrange(10 ..< 18, with: bothEndian32(size))
        d.replaceSubrange(18 ..< 25, with: recordDate(date))
        d[25] = isDirectory ? 2 : 0
        d.replaceSubrange(28 ..< 32, with: bothEndian16(1))
        d[32] = UInt8(name.count)
        d.replaceSubrange(33 ..< 33 + name.count, with: name)
        return d
    }

    /// Level 1 name: up to 8 upper case characters, extension and version, e.g. "USER_DAT.;1"
    private static func primaryName(_ name: String) -> [UInt8] {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        let parts = name.uppercased().split(separator: ".", maxSplits: 1).map { String($0.map { allowed.contains($0) ? $0 : "_" }) }
        let base = String((parts.first ?? "").prefix(8))
        let ext = parts.count > 1 ? String(parts[1].prefix(3)) : ""
        return Array((base + "." + ext + ";1").utf8)
    }

    private static func jolietName(_ name: String) -> [UInt8] {
        ucs2(String(name.prefix(64)))
    }

    private static func text(_ string: String, length: Int, joliet: Bool) -> [UInt8] {
        if joliet {
            var bytes = ucs2(String(string.prefix(length / 2)))
            while bytes.count < length {
                bytes += [0x00, 0x20]
            }
            return bytes
        }
        return Array(string.utf8.prefix(length)) + Array(repeating: 0x20, count: max(0, length - string.utf8.count))
    }

    private static func ucs2(_ string: String) -> [UInt8] {
        string.utf16.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
    }

    private static func utcComponents(_ date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    private static func recordDate(_ date: Date) -> [UInt8] {
        let c = utcComponents(date)
        return [UInt8(c.year! - 1900), UInt8(c.month!), UInt8(c.day!), UInt8(c.hour!), UInt8(c.minute!), UInt8(c.second!), 0]
    }

    private static func descriptorDate(_ date: Date) -> [UInt8] {
        let c = utcComponents(date)
        let digits = String(format: "%04d%02d%02d%02d%02d%02d00", c.year!, c.month!, c.day!, c.hour!, c.minute!, c.second!)
        return Array(digits.utf8) + [0]
    }

    private static func littleEndian32(_ value: Int) -> [UInt8] {
        withUnsafeBytes(of: UInt32(value).littleEndian, Array.init)
    }

    private static func bigEndian32(_ value: Int) -> [UInt8] {
        withUnsafeBytes(of: UInt32(value).bigEndian, Array.init)
    }

    private static func bothEndian32(_ value: Int) -> [UInt8] {
        littleEndian32(value) + bigEndian32(value)
    }

    private static func bothEndian16(_ value: Int) -> [UInt8] {
        withUnsafeBytes(of: UInt16(value).littleEndian, Array.init) + withUnsafeBytes(of: UInt16(value).bigEndian, Array.init)
    }
}
