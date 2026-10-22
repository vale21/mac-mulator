//
//  VirtualizationFrameworkDiskImageManager.swift
//  MacMulator
//
//  Created by Vale on 27/06/23.
//

import DiskImageKit
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
                callback(-1, "Failed to create ASIF disk image: \(error)")
            }
        } else {
            let shell = Shell()
            let command = "/usr/sbin/diskutil image create blank --fs none --format ASIF --size " + String(virtualDrive.size) + "GiB " + Utils.escape(drivePath)

            shell.runCommand(command, path, uponCompletion: callback)
        }
    }

    private func createRAWDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let drivePath = path + "/" + virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION
        if #available(macOS 27.0, *) {
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
                callback(-1, "Failed to create RAW disk image: \(error)")
            }
        } else {
            // Fallback to qemu-img for RAW images on macOS < 27.0, since diskutil does not support creating RAW images.
            QemuDiskImageManager().createDiskImage(virtualDrive, path, uponCompletion: callback)
        }
    }

    func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let newSizeInBytes = Int(virtualDrive.size) * 1000 * 1000 * 1000

        if #available(macOS 27.0, *) {
            DispatchQueue.global().async {
                do {
                    let diskImage = try DiskImage(opening: .open(url: URL(fileURLWithPath: virtualDrive.path), mode: .readWrite))
                    try diskImage.truncate(blockCount: newSizeInBytes / diskImage.blockSize.rawValue)
                    callback(0, nil)
                } catch {
                    print("Failed to resize disk image: \(error)")
                    callback(-1, "Failed to resize disk image: \(error)")
                }
            }
        } else {
            #if APPSTORE
                if virtualDrive.format == QemuConstants.FORMAT_RAW {
                    // Fallback to qemu-img for RAW images on macOS < 27.0 inside the App Store sandbox, since diskutil does not support resizing RAW images.
                    QemuDiskImageManager().resizeDiskImage(virtualDrive, path, shrink: shrink, uponCompletion: callback)
                } else {
                    print("Cannot resize disk image of format \(virtualDrive.format) inside the App Store sandbox on macOS < 27.0")
                    callback(-1, "Cannot resize disk image of format \(virtualDrive.format) inside the App Store sandbox on macOS < 27.0")
                }
            #else
                let shell = Shell()

                let command = "/usr/sbin/diskutil image resize --size " + String(virtualDrive.size) + "GiB " + Utils.escape(virtualDrive.path)

                shell.runCommand(command, path, uponCompletion: callback)
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
                print("Failed to replace disk image with converted " + format + " image: \(error)")
                try? FileManager.default.removeItem(atPath: tempPath)
                callback(-1, "Failed to replace disk image with converted " + format + " image: \(error)")
            }
        })
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

    private func parseConversionProgress(_ output: String) -> Double? {
        let marker = "% completed]"
        guard let markerRange = output.range(of: marker, options: .backwards),
              let openBracket = output.range(of: "[", options: .backwards, range: output.startIndex ..< markerRange.lowerBound)
        else {
            return nil
        }
        return Double(output[openBracket.upperBound ..< markerRange.lowerBound].trimmingCharacters(in: .whitespaces))
    }

    func getDiskImageInfo(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void) {
        getDiskImageInfo(virtualDrive.path, path, virtualDrive: virtualDrive, uponCompletion: callback)
    }

    private func getDiskImageInfo(_ drivePath: String, _ path: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32, String) -> Void) {
        if #available(macOS 27.0, *) {
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
                        format: String(describing: diskImage.format).uppercased(),
                        sectorCount: diskImage.blockCount,
                        blockSize: diskImage.blockSize.rawValue,
                        identityInfo: identityInfo
                    ))
                } catch {
                    callback(-1, "Failed to read disk image info: \(error)")
                }
            }
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

                shell.runCommand(command, path, uponCompletion: { terminationCcode in
                    callback(terminationCcode, terminationCcode == 0 ? shell.readFromStandardOutput() : shell.readFromConsole())
                })
            #endif
        }
    }

    private func formatDiskImageInfo(_ drivePath: String, format: String, sectorCount: Int, blockSize: Int, identityInfo: [(String, String)] = []) -> String {
        var info = formatHeader(format)

        info += "\n\tIdentity Info:\n"
        for (key, value) in identityInfo {
            info += "\t\t" + key + ": " + value + "\n"
        }

        let totalBytes = sectorCount * blockSize
        let (logical, allocated) = fileSizes(drivePath) ?? (0, nil)

        info += "\n\tSize Info:\n"
        info += "\t\tEmpty Bytes: " + String(totalBytes - (allocated ?? logical)) + "\n"
        info += "\t\tBlock Size: \(blockSize)\n"
        info += "\t\tSector Count: \(sectorCount)\n"
        info += "\t\tTotal Bytes: " + String(totalBytes) + "\n"
        info += formatFileSizes(logical: logical, allocated: allocated)

        return info
    }

    private func formatBasicDiskImageInfo(_ drivePath: String, virtualDrive: VirtualDrive?) -> String {
        var info = formatHeader(virtualDrive?.format.uppercased())

        info += "\n\tSize Info:\n"
        if let virtualDrive {
            info += "\t\tConfigured Size: " + String(Int(virtualDrive.size) * 1000 * 1000 * 1000) + "\n"
        }
        let (logical, allocated) = fileSizes(drivePath) ?? (0, nil)
        info += formatFileSizes(logical: logical, allocated: allocated)

        return info
    }

    private func formatHeader(_ format: String?) -> String {
        var info = "Image Format: " + (format ?? "Unknown") + "\n"
        if format == "ASIF" {
            info += "Format Description: Apple sparse image\n"
        }
        return info
    }

    private func formatFileSizes(logical: Int, allocated: Int?) -> String {
        var info = "\t\tFile Size: " + String(logical) + "\n"
        if let allocated {
            info += "\t\tAllocated On Disk: " + String(allocated) + "\n"
        }
        return info
    }

    private func fileSizes(_ path: String) -> (logical: Int, allocated: Int?)? {
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
        guard let logical = values?.fileSize else { return nil }
        return (logical, values?.totalFileAllocatedSize)
    }
}
