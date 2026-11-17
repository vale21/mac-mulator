//
//  DiskImageManager.swift
//  MacMulator
//
//  Created by Vale on 22/10/26.
//

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

    func importDiskImageWithQemuImg(from sourcePath: String, details: DiskImageDetails, to destinationPath: String, targetFormat: String, qemuPath: String, progress: @escaping (Double) -> Void, uponCompletion callback: @escaping (Int32, String?) -> Void) {
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
}
