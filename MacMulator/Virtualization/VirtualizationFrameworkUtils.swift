//
//  VirtualizationFrameworkUtils.swift
//  MacMulator
//
//  Created by Vale on 27/06/23.
//

import Foundation
import DiskImageKit

class VirtualizationFrameworkUtils {
    @available(macOS 16.0, *)
    static func createASIFDiskImage(path: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32) -> Void) {

        let drivePath = path + "/" + virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION
        
        if #available(macOS 27.0, *) {
            let blockSize: Int = 512
            let blockCount = Int(virtualDrive.size) * 1024 * 1024 * 1024 / blockSize
            
            do {
                _ = try DiskImage(
                    creating: .asif(
                        url: URL(fileURLWithPath: drivePath),
                        blockCount: Int(blockCount),
                        blockSize: .bytes512
                    )
                )
                callback(0)
            } catch {
                print("Failed to create ASIF disk image: \(error)")
                callback(-1)
            }
        } else {
            let shell = Shell()
            let command = "/usr/sbin/diskutil image create blank --fs none --format ASIF --size " + String(virtualDrive.size) + "GiB " + Utils.escape(drivePath)
            
            shell.runCommand(command, path, uponCompletion: callback)
        }
    }

    static func createRAWDiskImage(path: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32) -> Void) {
        let drivePath = path + "/" + virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION
        if #available(macOS 27.0, *) {
            let blockSize: Int = 512
            let blockCount = Int(virtualDrive.size) * 1024 * 1024 * 1024 / blockSize
            
            do {
                _ = try DiskImage(
                    creating: .raw(
                        url: URL(fileURLWithPath: drivePath),
                        blockCount: Int(blockCount)
                    )
                )
                callback(0)
            } catch {
                print("Failed to create RAW disk image: \(error)")
                callback(-1)
            }
        } else {
            let diskFd = open(drivePath, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
            if diskFd == -1 {
                callback(-1)
            }
            
            var result = ftruncate(diskFd, Int64(virtualDrive.size) * 1024 * 1024 * 1024)
            if result != 0 {
                callback(-1)
            }
            
            result = close(diskFd)
            if result != 0 {
                callback(-1)
            }
            callback(0)
        }
    }

    static func updateDiskImage(oldVirtualDrive: VirtualDrive, newVirtualDrive: VirtualDrive, path: String, uponCompletion callback: @escaping (Int32) -> Void) {
        if newVirtualDrive.size != oldVirtualDrive.size {
            resizeDiskImage(newVirtualDrive, path, shrink: newVirtualDrive.size < oldVirtualDrive.size, uponCompletion: callback)
        } else {
            callback(0)
        }
    }

    static func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, uponCompletion callback: @escaping (Int32) -> Void) {
        let newSizeInBytes = Int(virtualDrive.size) * 1024 * 1024 * 1024

        if #available(macOS 27.0, *) {
            DispatchQueue.global().async {
                do {
                    let diskImage = try DiskImage(opening: .open(url: URL(fileURLWithPath: virtualDrive.path), mode: .readWrite))
                    try diskImage.truncate(blockCount: newSizeInBytes / diskImage.blockSize.rawValue)
                    callback(0)
                } catch {
                    print("Failed to resize disk image: \(error)")
                    callback(-1)
                }
            }
        } else {
            #if APPSTORE
                // diskutil cannot attach images from inside the App Sandbox (com.apple.storagekitd lookup is denied),
                // so on older systems the ASIF header is updated directly.
                DispatchQueue.global().async {
                    callback(growASIFDiskImage(virtualDrive.path, newSizeInBytes: newSizeInBytes, shrink: shrink))
                }
            #else
                let shell = Shell()

                let command = "/usr/sbin/diskutil image resize --size " + String(virtualDrive.size) + "GiB " + Utils.escape(virtualDrive.path)

                shell.runCommand(command, path, uponCompletion: callback)
            #endif
        }
    }

    @available(macOS 16.0, *)
    static func convertASIFDiskImageToRAW(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32) -> Void) {
        let drivePath = virtualDrive.path
        // diskutil does not support in-place conversion from ASIF to RAW, so convert into a temporary file first.
        let tempPath = (drivePath as NSString).deletingPathExtension + "-raw-conversion." + MacMulatorConstants.DISK_EXTENSION
        try? FileManager.default.removeItem(atPath: tempPath)

        let shell = Shell()

        let command = "/usr/sbin/diskutil image create from --format RAW " + Utils.escape(drivePath) + " " + Utils.escape(tempPath)

        shell.runCommand(command, path, uponCompletion: { terminationCode in
            guard terminationCode == 0 else {
                print("Failed to convert disk image to RAW: " + shell.readFromConsole())
                try? FileManager.default.removeItem(atPath: tempPath)
                callback(terminationCode)
                return
            }

            do {
                _ = try FileManager.default.replaceItemAt(URL(fileURLWithPath: drivePath), withItemAt: URL(fileURLWithPath: tempPath))
                callback(0)
            } catch {
                print("Failed to replace disk image with converted RAW image: \(error)")
                try? FileManager.default.removeItem(atPath: tempPath)
                callback(-1)
            }
        })
    }

    static func getDiskImageInfo(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void) {
        getDiskImageInfo(virtualDrive.path, path, uponCompletion: callback)
    }

    static func getDiskImageInfo(_ drivePath: String, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void) {
        if #available(macOS 27.0, *) {
            DispatchQueue.global().async {
                do {
                    let diskImage = try DiskImage(opening: .open(url: URL(fileURLWithPath: drivePath), mode: .readOnly))

                    // Layer details are only meaningful for images that are part of a stack.
                    var layerInfo: [(String, String)] = []
                    if let layerType = diskImage.layerType {
                        layerInfo.append(("Layer Type", layerType == .cache ? "Cache" : "Overlay"))
                        if let layerUUID = diskImage.layerUUID {
                            layerInfo.append(("Layer UUID", layerUUID.uuidString))
                        }
                        if let parentUUID = diskImage.parentUUID {
                            layerInfo.append(("Parent UUID", parentUUID.uuidString))
                        }
                    }

                    callback(0, formatDiskImageInfo(
                        drivePath,
                        format: String(describing: diskImage.format).uppercased(),
                        sectorCount: diskImage.blockCount,
                        blockSize: diskImage.blockSize.rawValue,
                        layerInfo: layerInfo
                    ))
                } catch {
                    callback(-1, "Failed to read disk image info: \(error)")
                }
            }
        } else {
            #if APPSTORE
                // diskutil cannot attach images from inside the App Sandbox (com.apple.storagekitd lookup is denied),
                // so on older systems the image header is read directly.
                DispatchQueue.global().async {
                    if let header = readASIFHeader(drivePath) {
                        callback(0, formatDiskImageInfo(drivePath, format: "ASIF", sectorCount: header.sectorCount, blockSize: header.blockSize))
                    } else if let size = fileSizes(drivePath)?.logical {
                        callback(0, formatDiskImageInfo(drivePath, format: "RAW", sectorCount: size / 512, blockSize: 512))
                    } else {
                        callback(-1, "Failed to read disk image info.")
                    }
                }
            #else
                let shell = Shell()

                let command = "/usr/sbin/diskutil image info " + Utils.escape(drivePath)

                shell.runCommand(command, path, uponCompletion: { terminationCcode in
                    callback(terminationCcode, terminationCcode == 0 ? shell.readFromStandardOutput() : shell.readFromConsole())
                })
            #endif
        }
    }

    /// Builds a diskutil-like description of a disk image, using only data that can be read from inside the App Sandbox.
    /// RAW images are normally described by qemu-img; they only end up here when qemu-img is not available.
    fileprivate static func formatDiskImageInfo(_ drivePath: String, format: String, sectorCount: Int, blockSize: Int, layerInfo: [(String, String)] = []) -> String {
        let asifHeader = format == "ASIF" ? readASIFHeader(drivePath) : nil
        let sizes = fileSizes(drivePath)

        var info = "Image Format: " + format + "\n"
        if asifHeader != nil {
            info += "Format Description: Apple sparse image\n"
        }

        if let asifHeader {
            info += "\n\tIdentity Info:\n"
            info += "\t\tUUID: " + asifHeader.uuid.uuidString + "\n"
        }

        info += "\n\tSize Info:\n"
        info += "\t\tBlock Size: \(blockSize)\n"
        info += "\t\tSector Count: \(sectorCount)\n"
        info += "\t\tTotal Bytes: " + formatBytes(sectorCount * blockSize) + "\n"
        if let sizes {
            info += "\t\tFile Size: " + formatBytes(sizes.logical) + "\n"
            if let allocated = sizes.allocated {
                info += "\t\tAllocated On Disk: " + formatBytes(allocated) + "\n"
            }
        }

        if let asifHeader {
            info += "\n\tASIF Info:\n"
            info += "\t\tVersion: \(asifHeader.version)\n"
            info += "\t\tHeader Size: \(asifHeader.headerSize)\n"
            info += "\t\tChunk Size: \(asifHeader.chunkSize)\n"
            info += "\t\tMax Sector Count: \(asifHeader.maxSectorCount)\n"
        }

        if !layerInfo.isEmpty {
            info += "\n\tLayer Info:\n"
            for (key, value) in layerInfo {
                info += "\t\t" + key + ": " + value + "\n"
            }
        }

        return info
    }

    fileprivate static func formatBytes(_ bytes: Int) -> String {
        "\(bytes) (" + ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) + ")"
    }

    /// Returns the logical size of the file and the space it actually occupies on disk (sparse files take less).
    fileprivate static func fileSizes(_ path: String) -> (logical: Int, allocated: Int?)? {
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
        guard let logical = values?.fileSize else { return nil }
        return (logical, values?.totalFileAllocatedSize)
    }

    // MARK: - ASIF header access (used where DiskImageKit and diskutil are unavailable)

    // Layout of the ASIF header fields used here (all values are big-endian):
    //   0: magic "shdw" (4 bytes)       4: version (UInt32)
    //   8: header size (UInt32)        32: UUID (16 bytes)
    //  48: sector count (UInt64)        56: max sector count (UInt64)
    //  64: chunk size (UInt32)          68: block size (UInt16)
    // Resizing an image with diskutil only rewrites the sector count field.
    fileprivate static let asifMagic: [UInt8] = Array("shdw".utf8)
    fileprivate static let asifHeaderLength = 72
    fileprivate static let asifSectorCountOffset: UInt64 = 48

    fileprivate struct ASIFHeader {
        let version: Int
        let headerSize: Int
        let uuid: UUID
        let sectorCount: Int
        let maxSectorCount: Int
        let chunkSize: Int
        let blockSize: Int
    }

    fileprivate static func readASIFHeader(_ path: String) -> ASIFHeader? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: asifHeaderLength), data.count == asifHeaderLength else { return nil }
        let bytes = [UInt8](data)
        guard Array(bytes[0 ..< 4]) == asifMagic, readBigEndian(bytes, 4, 4) == 1 else { return nil }

        let blockSize = Int(readBigEndian(bytes, 68, 2))
        guard blockSize > 0 else { return nil }

        return ASIFHeader(
            version: Int(readBigEndian(bytes, 4, 4)),
            headerSize: Int(readBigEndian(bytes, 8, 4)),
            uuid: NSUUID(uuidBytes: Array(bytes[32 ..< 48])) as UUID,
            sectorCount: Int(readBigEndian(bytes, 48, 8)),
            maxSectorCount: Int(readBigEndian(bytes, 56, 8)),
            chunkSize: Int(readBigEndian(bytes, 64, 4)),
            blockSize: blockSize
        )
    }

    fileprivate static func growASIFDiskImage(_ path: String, newSizeInBytes: Int, shrink: Bool) -> Int32 {
        guard let header = readASIFHeader(path) else {
            print("Failed to resize disk image: not a valid ASIF image")
            return -1
        }

        let newSectorCount = newSizeInBytes / header.blockSize
        // Shrinking would require discarding allocated chunks, which only diskutil/DiskImageKit can do safely.
        guard !shrink, newSectorCount >= header.sectorCount, newSectorCount <= header.maxSectorCount else {
            print("Failed to resize disk image: shrinking ASIF images requires macOS 27 or later")
            return -1
        }

        guard let handle = FileHandle(forUpdatingAtPath: path) else { return -1 }
        defer { try? handle.close() }

        do {
            var value = UInt64(newSectorCount).bigEndian
            try handle.seek(toOffset: asifSectorCountOffset)
            try handle.write(contentsOf: Data(bytes: &value, count: MemoryLayout<UInt64>.size))
            try handle.synchronize()
            return 0
        } catch {
            print("Failed to resize disk image: \(error)")
            return -1
        }
    }

    fileprivate static func readBigEndian(_ bytes: [UInt8], _ offset: Int, _ length: Int) -> UInt64 {
        bytes[offset ..< offset + length].reduce(0) { ($0 << 8) | UInt64($1) }
    }
}
