//
//  DiskImageManager.swift
//  MacMulator
//
//  Created by Vale on 22/10/26.
//

#if arch(arm64)
    import DiskImageKit
#endif
import Foundation

struct DiskImageDetails {
    let format: String
    let virtualSize: Int64
    let hasBackingFile: Bool
    var metadata: VirtualDrive?
}

protocol DiskImageManager {
    func createDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func createLinkedDiskImage(_ virtualDrive: VirtualDrive, backingDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func flattenLinkedDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func getDiskImageInfo(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void)
}

extension DiskImageManager {
    func updateDiskImage(oldVirtualDrive: VirtualDrive, newVirtualDrive: VirtualDrive, path: String, progress: ((Double) -> Void)? = nil, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let resizeIfNeeded: (Int32) -> Void = { terminationCode in
            guard terminationCode == 0, newVirtualDrive.size != oldVirtualDrive.size else {
                callback(terminationCode, "Resize failed, or no resize needed.")
                return
            }
            self.resizeDiskImage(newVirtualDrive, path, shrink: newVirtualDrive.size < oldVirtualDrive.size, progress: progress, uponCompletion: callback)
        }

        if newVirtualDrive.format != oldVirtualDrive.format {
            // Overlay layers depend on the format of the drive they sit on, so they can't be converted.
            guard !oldVirtualDrive.isLinked else {
                callback(-1, NSLocalizedString("DiskImageManager.convertLinkedFailed", comment: ""))
                return
            }
            DiskImageConverter().convert(newVirtualDrive, from: oldVirtualDrive.format, progress: progress, uponCompletion: { terminationCode, errorMessage in
                guard terminationCode == 0 else {
                    callback(terminationCode, errorMessage)
                    return
                }
                resizeIfNeeded(0)
            })
        } else {
            resizeIfNeeded(0)
        }
    }

    func getDiskImageDetails(_ imagePath: String, qemuPath: String, uponCompletion callback: @escaping (DiskImageDetails?, String?) -> Void) {
        let metadata = VirtualDrive.readMetadata(fromImageAt: imagePath)
        let complete: (DiskImageDetails?, String?) -> Void = { details, errorMessage in
            callback(details.map { DiskImageDetails(format: $0.format, virtualSize: $0.virtualSize, hasBackingFile: $0.hasBackingFile || metadata?.isLinked == true, metadata: metadata) }, errorMessage)
        }

        if isAsifImage(imagePath) {
            asifDetails(imagePath, uponCompletion: { virtualSize, isLinked in
                complete(DiskImageDetails(format: QemuConstants.FORMAT_ASIF, virtualSize: virtualSize ?? self.fileSize(imagePath), hasBackingFile: isLinked), nil)
            })
            return
        }
        guard Utils.isQemuImgSupported(atPath: qemuPath) else {
            DispatchQueue.global(qos: .userInitiated).async {
                complete(self.detectDiskImageDetails(imagePath), nil)
            }
            return
        }

        let shell = Shell()
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_INFO + " --output=json")
            .withName(imagePath)
            .build()

        shell.runCommand(command, (imagePath as NSString).deletingLastPathComponent, uponCompletion: { terminationCode, errorMessage in
            guard terminationCode == 0,
                  let json = try? JSONSerialization.jsonObject(with: Data(shell.readFromStandardOutput().utf8)) as? [String: Any],
                  let format = json["format"] as? String,
                  let virtualSize = (json["virtual-size"] as? NSNumber)?.int64Value
            else {
                complete(nil, errorMessage ?? shell.readFromStandardError())
                return
            }
            complete(DiskImageDetails(format: format, virtualSize: virtualSize, hasBackingFile: json["backing-filename"] != nil), nil)
        })
    }

    private func detectDiskImageDetails(_ imagePath: String) -> DiskImageDetails {
        let handle = FileHandle(forReadingAtPath: imagePath)
        let header = [UInt8]((try? handle?.read(upToCount: 72)) ?? Data())
        try? handle?.close()
        func starts(with magic: String) -> Bool {
            header.starts(with: Array(magic.utf8))
        }

        // The format names are the ones of qemu-img
        let format: String = if header.starts(with: [0x51, 0x46, 0x49, 0xFB]) { // "QFI\xfb"
            // qcow (version 1) shares the magic with qcow2: Qemu opens it only as qcow, so it must be converted
            header.count >= 8 && header[4 ..< 8].elementsEqual([0, 0, 0, 1]) ? QemuConstants.FORMAT_QCOW : QemuConstants.FORMAT_QCOW2
        } else if starts(with: "KDMV") || starts(with: "# Disk DescriptorFile") {
            "vmdk"
        } else if starts(with: "vhdxfile") {
            "vhdx"
        } else if starts(with: "conectix") {
            "vpc"
        } else if header.count >= 68, header[64 ..< 68].elementsEqual([0x7F, 0x10, 0xDA, 0xBE]) {
            "vdi"
        } else {
            QemuConstants.FORMAT_RAW
        }

        guard format == QemuConstants.FORMAT_QCOW2 || format == QemuConstants.FORMAT_QCOW, header.count >= 32 else {
            return DiskImageDetails(format: format, virtualSize: fileSize(imagePath), hasBackingFile: false)
        }
        let bigEndian: (Int) -> UInt64 = { offset in header[offset ..< offset + 8].reduce(0) { $0 << 8 | UInt64($1) } }
        return DiskImageDetails(format: format, virtualSize: Int64(bigEndian(24)), hasBackingFile: bigEndian(8) != 0)
    }

    private func isAsifImage(_ imagePath: String) -> Bool {
        if (imagePath as NSString).pathExtension.lowercased() == QemuConstants.FORMAT_ASIF.lowercased() {
            return true
        }
        let handle = FileHandle(forReadingAtPath: imagePath)
        defer { try? handle?.close() }
        return (try? handle?.read(upToCount: 4)) == Data("shdw".utf8)
    }

    private func asifDetails(_ imagePath: String, uponCompletion callback: @escaping (Int64?, Bool) -> Void) {
        // DiskImageKit also works in the App Store sandbox, where "diskutil image info" fails
        #if arch(arm64)
            if #available(macOS 27.0, *), let image = try? DiskImage(opening: .open(url: URL(fileURLWithPath: imagePath), mode: .readOnly)) {
                callback(Int64(image.blockCount) * Int64(image.blockSize.rawValue), image.parentUUID != nil)
                return
            }
        #endif
        let shell = Shell()
        shell.runCommand("/usr/sbin/diskutil image info --plist " + Utils.escape(imagePath), (imagePath as NSString).deletingLastPathComponent, uponCompletion: { terminationCode, _ in
            guard terminationCode == 0, let info = try? PropertyListSerialization.propertyList(from: Data(shell.readFromStandardOutput().utf8), format: nil) as? [String: Any] else {
                callback(nil, self.asifHeaderHasParent(imagePath))
                return
            }
            let virtualSize = ((info["Size Info"] as? [String: Any])?["Total Bytes"] as? NSNumber)?.int64Value
            callback(virtualSize, (info["Identity Info"] as? [String: Any])?["Parent UUID"] != nil)
        })
    }

    private func asifHeaderHasParent(_ imagePath: String) -> Bool {
        /// Last resort, when neither DiskImageKit nor diskutil can read the image. The layout is not documented, but it matches what they
        /// report: the UUID of the image is at 0x20, the one of its parent at 0x50 (all zeros in a standalone image).
        /// An image that cannot be read is not established to be standalone, so it counts as linked.
        let handle = FileHandle(forReadingAtPath: imagePath)
        defer { try? handle?.close() }
        guard let header = try? handle?.read(upToCount: 0x60), header.count == 0x60 else {
            return true
        }
        return header[0x50 ..< 0x60].contains { $0 != 0 }
    }

    private func fileSize(_ imagePath: String) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: imagePath)[.size] as? NSNumber)?.int64Value ?? 0
    }
}
