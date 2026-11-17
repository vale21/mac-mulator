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
        DispatchQueue.global(qos: .userInitiated).async {
            // qemu-img does not know ASIF, and is not needed to recognize the formats imported without it
            if (imagePath as NSString).pathExtension.lowercased() == QemuConstants.FORMAT_ASIF.lowercased() || !Utils.isQemuImgSupported(atPath: qemuPath) {
                callback(self.detectDiskImageDetails(imagePath), nil)
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: qemuPath + "/" + QemuConstants.QEMU_IMG)
            process.arguments = ["info", "--output=json", imagePath]
            let output = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = output
            process.standardError = errorPipe
            do {
                try process.run()
            } catch {
                callback(nil, error.localizedDescription)
                return
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let format = json["format"] as? String,
                  let virtualSize = (json["virtual-size"] as? NSNumber)?.int64Value
            else {
                callback(nil, String(decoding: errorData, as: UTF8.self))
                return
            }
            callback(DiskImageDetails(format: format, virtualSize: virtualSize, hasBackingFile: json["backing-filename"] != nil), nil)
        }
    }

    func copyOrConvertDiskImage(from sourcePath: String, details: DiskImageDetails, to destinationPath: String, targetFormat: String, qemuPath: String, progress: @escaping (Double) -> Void, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result: (Int32, String?)
                // An image layered on a backing file is only complete together with it: converting merges them
                = if details.format == targetFormat, !details.hasBackingFile
            {
                self.copyDiskImage(from: sourcePath, to: destinationPath, progress: progress)
            } else if Utils.isQemuImgSupported(atPath: qemuPath) {
                self.convertDiskImage(from: sourcePath, to: destinationPath, targetFormat: targetFormat, qemuPath: qemuPath, progress: progress)
            } else {
                (-1, String(format: NSLocalizedString("DiskImageManager.conversionRequiresQemuImg", comment: ""), details.format, targetFormat))
            }
            if result.0 != 0 {
                try? FileManager.default.removeItem(atPath: destinationPath)
            }
            callback(result.0, result.1)
        }
    }

    /// Best effort, without qemu-img: recognizes ASIF by its extension, and the formats that need qemu-img by their header,
    /// so that they are not copied as RAW. Anything else is RAW.
    private func detectDiskImageDetails(_ imagePath: String) -> DiskImageDetails {
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: imagePath)[.size] as? NSNumber)?.int64Value ?? 0
        if (imagePath as NSString).pathExtension.lowercased() == QemuConstants.FORMAT_ASIF.lowercased() {
            // An ASIF file is sparse: its virtual size comes from diskutil
            return DiskImageDetails(format: QemuConstants.FORMAT_ASIF, virtualSize: asifVirtualSize(imagePath) ?? fileSize, hasBackingFile: false)
        }

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
            return DiskImageDetails(format: format, virtualSize: fileSize, hasBackingFile: false)
        }
        let bigEndian: (Int) -> UInt64 = { offset in header[offset ..< offset + 8].reduce(0) { $0 << 8 | UInt64($1) } }
        return DiskImageDetails(format: format, virtualSize: Int64(bigEndian(24)), hasBackingFile: bigEndian(8) != 0)
    }

    private func asifVirtualSize(_ imagePath: String) -> Int64? {
        // DiskImageKit also works in the App Store sandbox, where "diskutil image info" fails
        #if arch(arm64)
            if #available(macOS 27.0, *), let image = try? DiskImage(opening: .open(url: URL(fileURLWithPath: imagePath), mode: .readOnly)) {
                return Int64(image.blockCount) * Int64(image.blockSize.rawValue)
            }
        #endif
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["image", "info", "--plist", imagePath]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        return ((info?["Size Info"] as? [String: Any])?["Total Bytes"] as? NSNumber)?.int64Value
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

    private func convertDiskImage(from sourcePath: String, to destinationPath: String, targetFormat: String, qemuPath: String, progress: @escaping (Double) -> Void) -> (Int32, String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: qemuPath + "/" + QemuConstants.QEMU_IMG)
        // -p prints the progress as "(12.34/100%)"
        process.arguments = ["convert", "-p", "-O", targetFormat, sourcePath, destinationPath]
        let output = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = output
        process.standardError = errorPipe

        let progressRegex = try? NSRegularExpression(pattern: #"\((\d+(?:\.\d+)?)/100%\)"#)
        output.fileHandleForReading.readabilityHandler = { handle in
            let text = String(decoding: handle.availableData, as: UTF8.self)
            let range = NSRange(text.startIndex..., in: text)
            if let match = progressRegex?.matches(in: text, range: range).last,
               let valueRange = Range(match.range(at: 1), in: text), let value = Double(text[valueRange])
            {
                progress(value)
            }
        }
        defer { output.fileHandleForReading.readabilityHandler = nil }

        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, process.terminationStatus == 0 ? nil : String(decoding: errorData, as: UTF8.self))
    }
}
