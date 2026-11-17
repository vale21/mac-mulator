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
}

protocol DiskImageManager {
    func createDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func createLinkedDiskImage(_ virtualDrive: VirtualDrive, backingDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func flattenLinkedDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func convertDiskImage(_ virtualDrive: VirtualDrive, _ path: String, fromFormat oldFormat: String, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func getDiskImageInfo(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void)

    func importDiskImage(from sourcePath: String, details: DiskImageDetails, into virtualDrive: VirtualDrive, qemuPath: String, progress: @escaping (Double) -> Void, uponCompletion callback: @escaping (Int32, String?) -> Void)
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
            convertDiskImage(newVirtualDrive, path, fromFormat: oldVirtualDrive.format, progress: progress, uponCompletion: { terminationCode, errorMessage in
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
        // qemu-img does not know ASIF: it is recognized by its extension
        if (imagePath as NSString).pathExtension.lowercased() == QemuConstants.FORMAT_ASIF.lowercased() {
            asifVirtualSize(imagePath, uponCompletion: { virtualSize in
                callback(DiskImageDetails(format: QemuConstants.FORMAT_ASIF, virtualSize: virtualSize ?? self.fileSize(imagePath), hasBackingFile: false), nil)
            })
            return
        }
        guard Utils.isQemuImgSupported(atPath: qemuPath) else {
            DispatchQueue.global(qos: .userInitiated).async {
                callback(self.detectDiskImageDetails(imagePath), nil)
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
                callback(nil, errorMessage ?? shell.readFromStandardError())
                return
            }
            callback(DiskImageDetails(format: format, virtualSize: virtualSize, hasBackingFile: json["backing-filename"] != nil), nil)
        })
    }

    func copyOrConvertDiskImage(from sourcePath: String, details: DiskImageDetails, to destinationPath: String, targetFormat: String, qemuPath: String, progress: @escaping (Double) -> Void, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let finish: (Int32, String?) -> Void = { terminationCode, errorMessage in
            if terminationCode != 0 {
                try? FileManager.default.removeItem(atPath: destinationPath)
            }
            callback(terminationCode, errorMessage)
        }

        // An image layered on a backing file is only complete together with it: converting merges them
        if details.format == targetFormat, !details.hasBackingFile {
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.copyDiskImage(from: sourcePath, to: destinationPath, progress: progress)
                finish(result.0, result.1)
            }
        } else if Utils.isQemuImgSupported(atPath: qemuPath) {
            convertDiskImage(from: sourcePath, to: destinationPath, targetFormat: targetFormat, qemuPath: qemuPath, progress: progress, uponCompletion: finish)
        } else {
            finish(-1, String(format: NSLocalizedString("DiskImageManager.conversionRequiresQemuImg", comment: ""), details.format, targetFormat))
        }
    }

    /// Best effort, without qemu-img: recognizes the formats that need qemu-img by their header, so that they are not copied as RAW.
    /// Anything else is RAW.
    private func detectDiskImageDetails(_ imagePath: String) -> DiskImageDetails {
        let handle = FileHandle(forReadingAtPath: imagePath)
        let header = [UInt8]((try? handle?.read(upToCount: 72)) ?? Data())
        try? handle?.close()
        func starts(with magic: String) -> Bool {
            header.starts(with: Array(magic.utf8))
        }

        // The format names are the ones of qemu-img
        let format: String = if header.starts(with: [0x51, 0x46, 0x49, 0xFB]) { // "QFI\xfb"
            QemuConstants.FORMAT_QCOW2
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

        // The virtual size and backing file of a qcow2 image are in its header (big endian)
        guard format == QemuConstants.FORMAT_QCOW2, header.count >= 32 else {
            return DiskImageDetails(format: format, virtualSize: fileSize(imagePath), hasBackingFile: false)
        }
        let bigEndian: (Int) -> UInt64 = { offset in header[offset ..< offset + 8].reduce(0) { $0 << 8 | UInt64($1) } }
        return DiskImageDetails(format: format, virtualSize: Int64(bigEndian(24)), hasBackingFile: bigEndian(8) != 0)
    }

    /// An ASIF file is sparse: its virtual size is not the size of the file
    private func asifVirtualSize(_ imagePath: String, uponCompletion callback: @escaping (Int64?) -> Void) {
        // DiskImageKit also works in the App Store sandbox, where "diskutil image info" fails
        #if arch(arm64)
            if #available(macOS 27.0, *), let image = try? DiskImage(opening: .open(url: URL(fileURLWithPath: imagePath), mode: .readOnly)) {
                callback(Int64(image.blockCount) * Int64(image.blockSize.rawValue))
                return
            }
        #endif
        let shell = Shell()
        shell.runCommand("/usr/sbin/diskutil image info --plist " + Utils.escape(imagePath), (imagePath as NSString).deletingLastPathComponent, uponCompletion: { terminationCode, _ in
            let info = terminationCode == 0 ? try? PropertyListSerialization.propertyList(from: Data(shell.readFromStandardOutput().utf8), format: nil) as? [String: Any] : nil
            callback(((info?["Size Info"] as? [String: Any])?["Total Bytes"] as? NSNumber)?.int64Value)
        })
    }

    private func fileSize(_ imagePath: String) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: imagePath)[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func copyDiskImage(from sourcePath: String, to destinationPath: String, progress: (Double) -> Void) -> (Int32, String?) {
        let chunkSize = 16 * 1024 * 1024
        do {
            guard let input = FileHandle(forReadingAtPath: sourcePath) else {
                return (-1, String(format: NSLocalizedString("QemuDiskImageManager.cannotReadImage", comment: ""), sourcePath))
            }
            defer { try? input.close() }
            let totalSize = try (FileManager.default.attributesOfItem(atPath: sourcePath)[.size] as? NSNumber)?.int64Value ?? 0
            guard FileManager.default.createFile(atPath: destinationPath, contents: nil), let output = FileHandle(forWritingAtPath: destinationPath) else {
                return (-1, String(format: NSLocalizedString("QemuDiskImageManager.cannotWriteImage", comment: ""), destinationPath))
            }
            defer { try? output.close() }

            var copied: Int64 = 0
            while let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty {
                try output.write(contentsOf: chunk)
                copied += Int64(chunk.count)
                if totalSize > 0 {
                    progress(Double(copied) * 100 / Double(totalSize))
                }
            }
            return (0, nil)
        } catch {
            return (-1, error.localizedDescription)
        }
    }

    private func convertDiskImage(from sourcePath: String, to destinationPath: String, targetFormat: String, qemuPath: String, progress: @escaping (Double) -> Void, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let shell = Shell()
        // -p prints the progress as "(12.34/100%)"
        let progressRegex = try? NSRegularExpression(pattern: #"\((\d+(?:\.\d+)?)/100%\)"#)
        shell.outputHandler = { output in
            let range = NSRange(output.startIndex..., in: output)
            if let match = progressRegex?.matches(in: output, range: range).last,
               let valueRange = Range(match.range(at: 1), in: output), let value = Double(output[valueRange])
            {
                progress(value)
            }
        }

        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CONVERT + " -p")
            .withTargetFormat(targetFormat)
            .withName(sourcePath)
            .withTargetName(Utils.escape(destinationPath))
            .build()

        shell.runCommand(command, (destinationPath as NSString).deletingLastPathComponent, uponCompletion: { terminationCode, errorMessage in
            callback(terminationCode, terminationCode == 0 ? nil : (errorMessage ?? shell.readFromStandardError()))
        })
    }
}
