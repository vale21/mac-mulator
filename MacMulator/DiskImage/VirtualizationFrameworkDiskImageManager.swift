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
                            identityInfo.append(("Stable UUID", parentUUID.uuidString))
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
