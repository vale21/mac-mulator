//
//  VirtualizationFrameworkDiskImageManager.swift
//  MacMulator
//
//  Created by Vale on 27/06/23.
//

#if arch(arm64)
    import DiskImageKit
#endif
import Foundation
import Virtualization

class VirtualizationFrameworkDiskImageManager: DiskImageManager {
    func createDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        if #available(macOS 26.0, *), virtualDrive.format == QemuConstants.FORMAT_ASIF {
            createASIFDiskImage(virtualDrive, path, uponCompletion: callback)
        } else {
            createRAWDiskImage(virtualDrive, path, uponCompletion: callback)
        }
    }

    @available(macOS 26.0, *)
    private func createASIFDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let drivePath = path + "/" + virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION

        if #available(macOS 27.0, *) {
            #if arch(arm64)
                let blockSize = 512
                let blockCount = Int(virtualDrive.size) * 1000 * 1000 * 1000 / blockSize

                do {
                    _ = try DiskImage(
                        creating: .asif(
                            url: URL(fileURLWithPath: drivePath),
                            blockCount: Int(blockCount),
                            blockSize: .bytes512
                        )
                    )
                    callback(0, nil)
                } catch {
                    print("Failed to create ASIF disk image: \(error)")
                    callback(-1, String(format: NSLocalizedString("DiskImageManager.createAsifFailed", comment: ""), "\(error)"))
                }
            #endif
        } else {
            let shell = Shell()
            let command = "/usr/sbin/diskutil image create blank --fs none --format ASIF --size " + String(virtualDrive.size) + "GiB " + Utils.escape(drivePath)

            shell.runCommand(command, path, uponCompletion: callback)
        }
    }

    private func createRAWDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let drivePath = path + "/" + virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION
        if #available(macOS 27.0, *) {
            #if arch(arm64)
                let blockSize = 512
                let blockCount = Int(virtualDrive.size) * 1000 * 1000 * 1000 / blockSize

                do {
                    _ = try DiskImage(
                        creating: .raw(
                            url: URL(fileURLWithPath: drivePath),
                            blockCount: Int(blockCount)
                        )
                    )
                    callback(0, nil)
                } catch {
                    print("Failed to create RAW disk image: \(error)")
                    callback(-1, String(format: NSLocalizedString("DiskImageManager.createRawFailed", comment: ""), "\(error)"))
                }
            #endif
        } else {
            // Fallback to qemu-img for RAW images on macOS < 27.0, since diskutil does not support creating RAW images.
            QemuDiskImageManager().createDiskImage(virtualDrive, path, uponCompletion: callback)
        }
    }

    func createLinkedDiskImage(_ virtualDrive: VirtualDrive, backingDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        guard #available(macOS 27.0, *), virtualDrive.format == QemuConstants.FORMAT_ASIF, backingDrive.format == QemuConstants.FORMAT_ASIF else {
            callback(-1, NSLocalizedString("DiskImageManager.linkedNotSupported", comment: ""))
            return
        }
        #if arch(arm64)
            let overlayURL = URL(fileURLWithPath: path + "/" + virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION)
            DispatchQueue.global().async {
                do {
                    // The template is only read, so it's opened read-only and never modified.
                    let baseImage = try DiskImage(opening: .open(url: URL(fileURLWithPath: backingDrive.path), mode: .readOnly))
                    _ = try baseImage.appending(.asifLayer(url: overlayURL, type: .overlay))
                    callback(0, nil)
                } catch {
                    print("Failed to create ASIF overlay image: \(error)")
                    callback(-1, String(format: NSLocalizedString("DiskImageManager.createLinkedFailed", comment: ""), "\(error)"))
                }
            }
        #else
            callback(-1, NSLocalizedString("DiskImageManager.linkedNotSupported", comment: ""))
        #endif
    }

    /// Creates the storage attachment for a drive. Linked drives are overlay layers that have to be stacked
    /// on top of their template drive before being handed to the Virtualization framework.
    static func createDiskAttachment(for drive: VirtualDrive, readOnly: Bool = false) throws -> VZDiskImageStorageDeviceAttachment {
        #if arch(arm64)
            if #available(macOS 27.0, *), let backingPath = drive.backingPath {
                let baseImage = try DiskImage(opening: .open(url: URL(fileURLWithPath: backingPath), mode: .readOnly))
                let overlayImage = try DiskImage(opening: .open(url: URL(fileURLWithPath: drive.path), mode: readOnly ? .readOnly : .readWrite))
                let stackedImage = try baseImage.appending(overlayImage)
                return try VZDiskImageStorageDeviceAttachment(diskImage: stackedImage)
            }
        #endif
        return try VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: drive.path), readOnly: readOnly)
    }

    func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        if #available(macOS 27.0, *) {
            #if arch(arm64)
                DispatchQueue.global().async {
                    do {
                        let newSizeInBytes = Int(virtualDrive.size) * 1000 * 1000 * 1000
                        let diskImage = try DiskImage(opening: .open(url: URL(fileURLWithPath: virtualDrive.path), mode: .readWrite))
                        try diskImage.truncate(blockCount: newSizeInBytes / diskImage.blockSize.rawValue)
                        callback(0, nil)
                    } catch {
                        print("Failed to resize disk image: \(error)")
                        callback(-1, String(format: NSLocalizedString("DiskImageManager.resizeFailed", comment: ""), "\(error)"))
                    }
                }
            #endif
        } else {
            #if APPSTORE
                if virtualDrive.format == QemuConstants.FORMAT_RAW {
                    // Fallback to qemu-img for RAW images on macOS < 27.0 inside the App Store sandbox, since diskutil does not support resizing RAW images.
                    QemuDiskImageManager().resizeDiskImage(virtualDrive, path, shrink: shrink, progress: progress, uponCompletion: callback)
                } else {
                    // Convert to RAW, resize, and convert back to ASIF, since diskutil does not support resizing ASIF images on macOS < 27.0 inside the App Store sandbox.
                    virtualDrive.format = QemuConstants.FORMAT_RAW
                    convertDiskImage(virtualDrive, path, fromFormat: QemuConstants.FORMAT_ASIF, progress: progress.map { report in { report($0 / 2) } }, uponCompletion: { errorCode, errorMessage in
                        guard errorCode == 0 else {
                            callback(errorCode, errorMessage)
                            return
                        }
                        self.resizeDiskImage(virtualDrive, path, shrink: shrink, progress: nil, uponCompletion: { errorCode, errorMessage in
                            guard errorCode == 0 else {
                                callback(errorCode, errorMessage)
                                return
                            }
                            virtualDrive.format = QemuConstants.FORMAT_ASIF
                            self.convertDiskImage(virtualDrive, path, fromFormat: QemuConstants.FORMAT_RAW, progress: progress.map { report in { report(50 + $0 / 2) } }, uponCompletion: callback)
                        })
                    })
                }
            #else
                if virtualDrive.format == QemuConstants.FORMAT_RAW {
                    QemuDiskImageManager().resizeDiskImage(virtualDrive, path, shrink: shrink, progress: progress, uponCompletion: callback)
                    return
                } else {
                    let shell = Shell()

                    let command = "/usr/sbin/diskutil image resize --size " + String(virtualDrive.size) + "GiB " + Utils.escape(virtualDrive.path)

                    shell.runCommand(command, path, uponCompletion: callback)
                }
            #endif
        }
    }

    func convertDiskImage(_ virtualDrive: VirtualDrive, _ path: String, fromFormat _: String, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let drivePath = virtualDrive.path
        let format = virtualDrive.format

        // diskutil does not support in-place conversion between ASIF and RAW, so convert into a temporary file first.
        let tempPath = (drivePath as NSString).deletingPathExtension + "-" + format.lowercased() + "-conversion." + MacMulatorConstants.DISK_EXTENSION
        try? FileManager.default.removeItem(atPath: tempPath)

        // The App Store sandbox does not allow attaching disk images, so it falls back to a plain diskutil conversion,
        // which produces a fully allocated ASIF.
        #if !APPSTORE
            let convertsToSparseASIF = format == QemuConstants.FORMAT_ASIF
        #else
            let convertsToSparseASIF = false
        #endif
        if convertsToSparseASIF {
            convertToSparseASIF(drivePath, tempPath, path, progress: progress, uponCompletion: { terminationCode, errorMessage in
                guard terminationCode == 0 else {
                    try? FileManager.default.removeItem(atPath: tempPath)
                    callback(terminationCode, errorMessage)
                    return
                }
                self.replaceDiskImage(drivePath, with: tempPath, format: format, uponCompletion: callback)
            })
            return
        }

        let shell = Shell()
        if let progress {
            shell.outputHandler = { output in
                if let percentage = self.parseConversionProgress(output) {
                    progress(percentage)
                }
            }
        }

        let command = "/usr/sbin/diskutil image create from --format " + format + " " + Utils.escape(drivePath) + " " + Utils.escape(tempPath)

        shell.runCommand(command, path, uponCompletion: { terminationCode, errorMessage in
            guard terminationCode == 0 else {
                print("Failed to convert disk image to " + format + ": " + (errorMessage ?? shell.readFromStandardError()))
                try? FileManager.default.removeItem(atPath: tempPath)
                callback(terminationCode, errorMessage.map { self.pruneConversionProgress($0) })
                return
            }

            self.replaceDiskImage(drivePath, with: tempPath, format: format, uponCompletion: callback)
        })
    }

    private func replaceDiskImage(_ drivePath: String, with tempPath: String, format: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        do {
            _ = try FileManager.default.replaceItemAt(URL(fileURLWithPath: drivePath), withItemAt: URL(fileURLWithPath: tempPath))
            callback(0, nil)
        } catch {
            print(String(format: NSLocalizedString("DiskImageManager.replaceFailed", comment: ""), format, "\(error)"))
            try? FileManager.default.removeItem(atPath: tempPath)
            callback(-1, String(format: NSLocalizedString("DiskImageManager.replaceFailed", comment: ""), format, "\(error)"))
        }
    }

    /// Converts a RAW image into a sparse ASIF image.
    ///
    /// `diskutil image create from` copies every block of the source, zero-filled ones included, so the resulting
    /// ASIF ends up fully allocated (even slightly larger than the RAW file). Instead, create an empty unpartitioned
    /// ASIF, attach it as a device and copy the RAW contents with `dd conv=sparse`, which seeks over all-zero blocks
    /// rather than writing them, so they stay unallocated in the ASIF.
    private func convertToSparseASIF(_ sourcePath: String, _ destinationPath: String, _ path: String, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        guard let sourceSize = (try? FileManager.default.attributesOfItem(atPath: sourcePath))?[.size] as? Int else {
            callback(-1, "Unable to read the size of " + sourcePath)
            return
        }

        let createShell = Shell()
        let createCommand = "/usr/sbin/diskutil image create blank --fs None --format ASIF --size " + String(sourceSize) + " " + Utils.escape(destinationPath)
        createShell.runCommand(createCommand, path, uponCompletion: { terminationCode, errorMessage in
            guard terminationCode == 0 else {
                callback(terminationCode, errorMessage)
                return
            }

            let attachShell = Shell()
            let attachCommand = "/usr/sbin/diskutil image attach --noMount " + Utils.escape(destinationPath)
            attachShell.runCommand(attachCommand, path, uponCompletion: { terminationCode, errorMessage in
                // The first token of the output is the /dev node of the attached image (e.g. /dev/disk8).
                guard terminationCode == 0,
                      let device = attachShell.readFromStandardOutput().split(whereSeparator: \.isWhitespace).first.map(String.init),
                      device.hasPrefix("/dev/disk")
                else {
                    callback(terminationCode != 0 ? terminationCode : -1, errorMessage ?? attachShell.readFromStandardError())
                    return
                }

                let copyShell = Shell()
                if let progress {
                    copyShell.outputHandler = { output in
                        if let copiedBytes = self.parseCopyProgress(output), sourceSize > 0 {
                            progress(min(100, Double(copiedBytes) * 100 / Double(sourceSize)))
                        }
                    }
                }

                // Write through the raw device node, which is much faster than the buffered one.
                let rawDevice = device.replacingOccurrences(of: "/dev/disk", with: "/dev/rdisk")
                let copyCommand = "/bin/dd if=" + Utils.escape(sourcePath) + " of=" + rawDevice + " bs=1m conv=sparse status=progress"
                copyShell.runCommand(copyCommand, path, uponCompletion: { copyTerminationCode, copyErrorMessage in
                    // Always detach the image, even if the copy failed.
                    let detachShell = Shell()
                    detachShell.runCommand("/usr/sbin/diskutil eject " + device, path, uponCompletion: { detachTerminationCode, detachErrorMessage in
                        if copyTerminationCode != 0 {
                            callback(copyTerminationCode, copyErrorMessage)
                        } else {
                            callback(detachTerminationCode, detachErrorMessage)
                        }
                    })
                })
            })
        })
    }

    /// Parses the number of bytes copied so far from `dd status=progress` output (e.g. "448069632 bytes (448 MB, 427 MiB) transferred 1.004s, 446 MB/s").
    private func parseCopyProgress(_ output: String) -> Int? {
        let lines = output.split(whereSeparator: { $0 == "\r" || $0 == "\n" })
        for line in lines.reversed() {
            let tokens = line.split(separator: " ")
            if tokens.count >= 2, tokens[1] == "bytes", let bytes = Int(tokens[0]) {
                return bytes
            }
        }
        return nil
    }

    func getDiskImageInfo(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void) {
        getDiskImageInfo(virtualDrive.path, path, virtualDrive: virtualDrive, uponCompletion: callback)
    }

    private func parseConversionProgress(_ output: String) -> Double? {
        let marker = "% completed]"
        guard let markerRange = output.range(of: marker, options: .backwards),
              let openBracket = output.range(of: "[", options: .backwards, range: output.startIndex ..< markerRange.lowerBound)
        else {
            return nil
        }
        return Double(output[openBracket.upperBound ..< markerRange.lowerBound].trimmingCharacters(in: .whitespaces))
    }

    private func pruneConversionProgress(_ message: String) -> String {
        message
            .replacingOccurrences(of: "\\[\\s*\\d+(\\.\\d+)?% completed\\][ \\t]*", with: "", options: .regularExpression)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func getDiskImageInfo(_ drivePath: String, _ path: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32, String) -> Void) {
        if #available(macOS 27.0, *) {
            #if arch(arm64)
                DispatchQueue.global().async {
                    do {
                        let diskImage = try DiskImage(opening: .open(url: URL(fileURLWithPath: drivePath), mode: .readOnly))

                        // Layer details are only meaningful for images that are part of a stack.
                        var identityInfo: [(String, String)] = []
                        if let layerUUID = diskImage.layerUUID {
                            identityInfo.append(("UUID", layerUUID.uuidString))
                        }
                        if let parentUUID = diskImage.parentUUID {
                            identityInfo.append(("Parent UUID", parentUUID.uuidString))
                        }

                        if let backingPath = virtualDrive.backingPath {
                            identityInfo.append(("Template", backingPath))
                        }

                        callback(0, self.formatDiskImageInfo(
                            drivePath,
                            format: String(describing: diskImage.format),
                            sectorCount: diskImage.blockCount,
                            blockSize: diskImage.blockSize.rawValue,
                            identityInfo: identityInfo
                        ))
                    } catch {
                        callback(-1, String(format: NSLocalizedString("DiskImageManager.readInfoFailed", comment: ""), "\(error)"))
                    }
                }
            #endif
        } else {
            #if APPSTORE
                if virtualDrive.format == QemuConstants.FORMAT_RAW {
                    // fallback to qemu-img for RAW images on macOS < 27.0 inside the App Store sandbox, since diskutil does not support reading RAW image info.
                    QemuDiskImageManager().getDiskImageInfo(virtualDrive, path, uponCompletion: callback)
                } else {
                    DispatchQueue.global().async {
                        callback(0, self.formatBasicDiskImageInfo(drivePath, virtualDrive: virtualDrive))
                    }
                }
            #else
                let shell = Shell()

                let command = "/usr/sbin/diskutil image info " + Utils.escape(drivePath)

                shell.runCommand(command, path, uponCompletion: { terminationCcode, errorMessage in
                    callback(terminationCcode, terminationCcode == 0 ? shell.readFromStandardOutput() : errorMessage ?? shell.readFromStandardError())
                })
            #endif
        }
    }

    private func fileSizes(_ path: String) -> (logical: Int, allocated: Int?)? {
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
        guard let logical = values?.fileSize else { return nil }
        return (logical, values?.totalFileAllocatedSize)
    }

    private func formatDiskImageInfo(_ drivePath: String, format: String, sectorCount: Int, blockSize: Int, identityInfo: [(String, String)] = []) -> String {
        var info = formatHeader(format)

        if !identityInfo.isEmpty {
            info += "\n\tIdentity Info:\n"
        }
        for (key, value) in identityInfo {
            info += "\t\t" + key + ": " + value + "\n"
        }

        let totalBytes = sectorCount * blockSize
        let (logical, allocated) = fileSizes(drivePath) ?? (0, nil)

        info += "\n\tSize Info:\n"
        info += "\t\tEmpty Bytes: " + formatBytes(totalBytes - (allocated ?? logical)) + "\n"
        info += "\t\tBlock Size: \(blockSize)\n"
        info += "\t\tSector Count: \(sectorCount)\n"
        info += "\t\tTotal Bytes: " + formatBytes(totalBytes) + "\n"
        info += formatFileSizes(logical: logical, allocated: allocated)

        return info
    }

    private func formatBasicDiskImageInfo(_ drivePath: String, virtualDrive: VirtualDrive?) -> String {
        var info = formatHeader(virtualDrive?.format)

        info += "\n\tSize Info:\n"
        if let virtualDrive {
            info += "\t\tConfigured Size: " + formatBytes(Int(virtualDrive.size) * 1000 * 1000 * 1000) + "\n"
        }
        let (logical, allocated) = fileSizes(drivePath) ?? (0, nil)
        info += formatFileSizes(logical: logical, allocated: allocated)

        return info
    }

    private func formatHeader(_ format: String?) -> String {
        var info = "Image Format: " + (format ?? "Unknown") + "\n"
        if format == QemuConstants.FORMAT_ASIF {
            info += "Format Description: Apple sparse image\n"
        } else if format == QemuConstants.FORMAT_RAW {
            info += "Format Description: RAW read-write image\n"
        }
        return info
    }

    private func formatFileSizes(logical: Int, allocated: Int?) -> String {
        var info = "\t\tFile Size: " + formatBytes(logical) + "\n"
        if let allocated {
            info += "\t\tAllocated On Disk: " + formatBytes(allocated) + "\n"
        }
        return info
    }

    private func formatBytes(_ bytes: Int) -> String {
        "\(bytes) (" + ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) + ")"
    }
}
