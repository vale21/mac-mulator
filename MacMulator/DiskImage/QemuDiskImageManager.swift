//
//  QemuDiskImageManager.swift
//  MacMulator
//
//  Created by Vale on 22/10/26.
//

import Foundation

/// What "qemu-img info" tells about a disk image
struct DiskImageDetails {
    let format: String
    let virtualSize: Int64
    let hasBackingFile: Bool
}

class QemuDiskImageManager: DiskImageManager {
    func rebaseLinkedDiskImage(at imagePath: String, to backingPath: String, for virtualMachine: VirtualMachine) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: QemuUtils.getQemuPath(for: virtualMachine) + "/" + QemuConstants.QEMU_IMG)
        process.arguments = ["rebase", "-u", "-b", backingPath, imagePath]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "QemuDiskImageManager", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to update the backing file for \(imagePath)."])
        }
    }

    func createDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        createDiskImage(path: path, name: virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION, format: virtualDrive.format, size: String(virtualDrive.size) + "G", uponCompletion: callback)
    }

    func createLinkedDiskImage(_ virtualDrive: VirtualDrive, backingDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let qemuPath = QemuUtils.getQemuPath()
        let shell = Shell()

        // The overlay inherits its size from the backing file, so no size is specified.
        let command =
            QemuImgCommandBuilder(qemuPath: qemuPath)
                .withCommand(QemuConstants.IMAGE_CMD_CREATE)
                .withFormat(virtualDrive.format)
                .withBackingFile(backingDrive.path)
                .withBackingFormat(backingDrive.format)
                .withName(path + "/" + virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION)
                .build()

        shell.runCommand(command, path, uponCompletion: { terminationCode, errorMessage in
            callback(terminationCode, terminationCode == 0 ? nil : (errorMessage ?? shell.readFromStandardError()))
        })
    }

    func flattenLinkedDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        convertDiskImage(virtualDrive, path, fromFormat: virtualDrive.format, progress: nil, uponCompletion: callback)
    }

    func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, progress _: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let qemuPath = QemuUtils.getQemuPath()
        let shell = Shell()

        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_RESIZE)
            .withName(virtualDrive.path)
            .withShrinkArg(shrink)
            .withShortSize(String(virtualDrive.size) + "G")
            .build()

        shell.runCommand(command, path, uponCompletion: callback)
    }

    func convertDiskImage(_ virtualDrive: VirtualDrive, _ path: String, fromFormat oldFormat: String, progress _: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let drivePath = virtualDrive.path
        let format = virtualDrive.format

        // qemu-img cannot convert an image onto itself, so convert into a temporary file first.
        let tempPath = (drivePath as NSString).deletingPathExtension + "-" + format.lowercased() + "-conversion." + MacMulatorConstants.DISK_EXTENSION
        try? FileManager.default.removeItem(atPath: tempPath)

        let qemuPath = QemuUtils.getQemuPath()
        let shell = Shell()

        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CONVERT)
            .withFormat(oldFormat)
            .withTargetFormat(format)
            .withName(drivePath)
            .withTargetName(Utils.escape(tempPath))
            .build()

        shell.runCommand(command, path, uponCompletion: { terminationCode, errorMessage in
            guard terminationCode == 0 else {
                print("Failed to convert disk image to " + format + ": " + shell.readFromConsole())
                try? FileManager.default.removeItem(atPath: tempPath)
                callback(terminationCode, errorMessage)
                return
            }

            do {
                _ = try FileManager.default.replaceItemAt(URL(fileURLWithPath: drivePath), withItemAt: URL(fileURLWithPath: tempPath))
                callback(0, nil)
            } catch {
                print(String(format: NSLocalizedString("DiskImageManager.replaceFailed", comment: ""), format, "\(error)"))
                try? FileManager.default.removeItem(atPath: tempPath)
                callback(-1, String(format: NSLocalizedString("DiskImageManager.replaceFailed", comment: ""), format, "\(error)"))
            }
        })
    }

    func convertVHDXToDiskImage(vhdxPath: String, vmPath: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32, Int32) -> Void) {
        let qemuPath = QemuUtils.getQemuPath()
        let shell = Shell()

        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CONVERT)
            .withName(vhdxPath)
            .withTargetName(Utils.escape(virtualDrive.path))
            .build()

        shell.runCommand(command, vmPath, uponCompletion: {
            terminationCode, _ in

            if terminationCode == 0 {
                self.getDiskImageInfo(virtualDrive.path, vmPath, uponCompletion: {
                    infoCode, output in
                    if infoCode == 0 {
                        let driveSize = Utils.extractDriveSize(output)
                        if let driveSize {
                            callback(infoCode, driveSize)
                        } else {
                            callback(infoCode, -1)
                        }
                    } else {
                        callback(infoCode, -1)
                    }
                })
            } else {
                callback(terminationCode, -1)
            }

        })
    }

    func getDiskImageInfo(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void) {
        getDiskImageInfo(virtualDrive.path, path, uponCompletion: callback)
    }

    func getDiskImageInfo(_ drivePath: String, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void) {
        let qemuPath = QemuUtils.getQemuPath()
        let shell = Shell()

        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_INFO)
            .withName(drivePath)
            .build()

        shell.runCommand(command, path, uponCompletion: { terminationCode, errorMessage in
            callback(terminationCode, (terminationCode == 0 ? shell.readFromStandardOutput() : errorMessage) ?? shell.readFromStandardError())
        })
    }

    /// Reads format, virtual size and backing file of a disk image, with "qemu-img info"
    func getDiskImageDetails(_ imagePath: String, qemuPath: String, uponCompletion callback: @escaping (DiskImageDetails?, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
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

    /// Imports a disk image into the VM: copies it when it is already in the target format, converts it with qemu-img otherwise.
    /// The progress goes from 0 to 100. On failure the partially imported file is deleted.
    func importDiskImage(from sourcePath: String, details: DiskImageDetails, to destinationPath: String, targetFormat: String, qemuPath: String, progress: @escaping (Double) -> Void, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result: (Int32, String?)
                // An image layered on a backing file is only complete together with it: converting merges them
                = if details.format == targetFormat, !details.hasBackingFile
            {
                self.copyDiskImage(from: sourcePath, to: destinationPath, progress: progress)
            } else {
                self.convertDiskImage(from: sourcePath, to: destinationPath, targetFormat: targetFormat, qemuPath: qemuPath, progress: progress)
            }
            if result.0 != 0 {
                try? FileManager.default.removeItem(atPath: destinationPath)
            }
            callback(result.0, result.1)
        }
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

    private func createDiskImage(path: String, name: String, format: String, size: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let qemuPath = QemuUtils.getQemuPath()
        let shell = Shell()

        let command: String =
            QemuImgCommandBuilder(qemuPath: qemuPath)
                .withCommand(QemuConstants.IMAGE_CMD_CREATE)
                .withFormat(format)
                .withSize(size)
                .withName(name)
                .build()

        shell.runCommand(command, path, uponCompletion: callback)
    }
}
