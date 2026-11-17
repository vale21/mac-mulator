//
//  DiskImageConverter.swift
//  MacMulator
//
//  Created by Vale on 17/11/2026.
//

import Foundation

class DiskImageConverter {
    let qemuPath: String

    init(qemuPath: String = QemuUtils.getQemuPath()) {
        self.qemuPath = qemuPath
    }

    static func replaceDiskImage(_ drivePath: String, with tempPath: String, format: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        do {
            _ = try FileManager.default.replaceItemAt(URL(fileURLWithPath: drivePath), withItemAt: URL(fileURLWithPath: tempPath))
            callback(0, nil)
        } catch {
            print(String(format: NSLocalizedString("DiskImageManager.replaceFailed", comment: ""), format, "\(error)"))
            try? FileManager.default.removeItem(atPath: tempPath)
            callback(-1, String(format: NSLocalizedString("DiskImageManager.replaceFailed", comment: ""), format, "\(error)"))
        }
    }

    func convert(_ virtualDrive: VirtualDrive, from sourceFormat: String, progress: ((Double) -> Void)? = nil, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let drivePath = virtualDrive.path
        let format = virtualDrive.format

        // No tool converts an image onto itself: convert into a temporary file, then replace the image with it
        let tempPath = (drivePath as NSString).deletingPathExtension + "-" + format.lowercased() + "-conversion." + MacMulatorConstants.DISK_EXTENSION
        try? FileManager.default.removeItem(atPath: tempPath)
        convert(drivePath, from: sourceFormat, to: tempPath, format: format, hasBackingFile: virtualDrive.isLinked, progress: progress, uponCompletion: { terminationCode, errorMessage in
            guard terminationCode == 0 else {
                callback(terminationCode, errorMessage)
                return
            }
            DiskImageConverter.replaceDiskImage(drivePath, with: tempPath, format: format, uponCompletion: callback)
        })
    }

    func convert(_ sourcePath: String, from sourceFormat: String, to destinationPath: String, format targetFormat: String, hasBackingFile: Bool = false, progress: ((Double) -> Void)? = nil, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        guard !FileManager.default.fileExists(atPath: destinationPath) else {
            callback(-1, CocoaError(.fileWriteFileExists).localizedDescription)
            return
        }
        let finish: (Int32, String?) -> Void = { terminationCode, errorMessage in
            if terminationCode != 0 {
                try? FileManager.default.removeItem(atPath: destinationPath)
            }
            callback(terminationCode, errorMessage)
        }
        let involvesAsif = sourceFormat == QemuConstants.FORMAT_ASIF || targetFormat == QemuConstants.FORMAT_ASIF
        let involvesRaw = sourceFormat == QemuConstants.FORMAT_RAW || targetFormat == QemuConstants.FORMAT_RAW

        // An image layered on a backing file is only complete together with it: converting merges them
        if sourceFormat == targetFormat, !hasBackingFile {
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.copy(sourcePath, to: destinationPath, progress: progress)
                finish(result.0, result.1)
            }
        } else if involvesAsif, !involvesRaw {
            convertThroughRaw(sourcePath, from: sourceFormat, to: destinationPath, format: targetFormat, hasBackingFile: hasBackingFile, progress: progress, uponCompletion: finish)
        } else if involvesAsif {
            convertWithDiskutil(sourcePath, to: destinationPath, format: targetFormat, progress: progress, uponCompletion: finish)
        } else if Utils.isQemuImgSupported(atPath: qemuPath) {
            convertWithQemuImg(sourcePath, to: destinationPath, format: targetFormat, progress: progress, uponCompletion: finish)
        } else {
            finish(-1, String(format: NSLocalizedString("DiskImageManager.conversionRequiresQemuImg", comment: ""), sourceFormat, targetFormat))
        }
    }

    private func convertThroughRaw(_ sourcePath: String, from sourceFormat: String, to destinationPath: String, format targetFormat: String, hasBackingFile: Bool, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let rawPath = (destinationPath as NSString).deletingPathExtension + "-raw-conversion." + MacMulatorConstants.DISK_EXTENSION
        try? FileManager.default.removeItem(atPath: rawPath)
        convert(sourcePath, from: sourceFormat, to: rawPath, format: QemuConstants.FORMAT_RAW, hasBackingFile: hasBackingFile, progress: { progress?($0 / 2) }, uponCompletion: { terminationCode, errorMessage in
            guard terminationCode == 0 else {
                callback(terminationCode, errorMessage)
                return
            }
            self.convert(rawPath, from: QemuConstants.FORMAT_RAW, to: destinationPath, format: targetFormat, progress: { progress?(50 + $0 / 2) }, uponCompletion: { terminationCode, errorMessage in
                try? FileManager.default.removeItem(atPath: rawPath)
                callback(terminationCode, errorMessage)
            })
        })
    }

    private func convertWithDiskutil(_ sourcePath: String, to destinationPath: String, format targetFormat: String, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        // The App Store sandbox does not allow attaching disk images: there a plain diskutil conversion makes a fully allocated ASIF
        #if !APPSTORE
            if targetFormat == QemuConstants.FORMAT_ASIF {
                convertToSparseAsif(sourcePath, to: destinationPath, progress: progress, uponCompletion: callback)
                return
            }
        #endif

        let shell = Shell()
        if let progress {
            shell.outputHandler = { output in
                if let percentage = self.parseDiskutilProgress(output) {
                    progress(percentage)
                }
            }
        }

        let command = "/usr/sbin/diskutil image create from --format " + targetFormat + " " + Utils.escape(sourcePath) + " " + Utils.escape(destinationPath)
        shell.runCommand(command, (destinationPath as NSString).deletingLastPathComponent, uponCompletion: { terminationCode, errorMessage in
            callback(terminationCode, terminationCode == 0 ? nil : self.pruneDiskutilProgress(errorMessage ?? shell.readFromStandardError()))
        })
    }

    private func convertToSparseAsif(_ sourcePath: String, to destinationPath: String, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        guard let sourceSize = (try? FileManager.default.attributesOfItem(atPath: sourcePath))?[.size] as? Int else {
            callback(-1, "Unable to read the size of " + sourcePath)
            return
        }
        let path = (destinationPath as NSString).deletingLastPathComponent

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
                        if let copiedBytes = self.parseDdProgress(output), sourceSize > 0 {
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

    private func convertWithQemuImg(_ sourcePath: String, to destinationPath: String, format targetFormat: String, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let shell = Shell()
        if let progress {
            shell.outputHandler = { output in
                if let percentage = self.parseQemuImgProgress(output) {
                    progress(percentage)
                }
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

    private func copy(_ sourcePath: String, to destinationPath: String, progress: ((Double) -> Void)?) -> (Int32, String?) {
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
                    progress?(Double(copied) * 100 / Double(totalSize))
                }
            }
            return (0, nil)
        } catch {
            return (-1, error.localizedDescription)
        }
    }

    private func parseQemuImgProgress(_ output: String) -> Double? {
        let progressRegex = try? NSRegularExpression(pattern: #"\((\d+(?:\.\d+)?)/100%\)"#)
        let range = NSRange(output.startIndex..., in: output)
        guard let match = progressRegex?.matches(in: output, range: range).last,
              let valueRange = Range(match.range(at: 1), in: output)
        else {
            return nil
        }
        return Double(output[valueRange])
    }

    private func parseDiskutilProgress(_ output: String) -> Double? {
        let marker = "% completed]"
        guard let markerRange = output.range(of: marker, options: .backwards),
              let openBracket = output.range(of: "[", options: .backwards, range: output.startIndex ..< markerRange.lowerBound)
        else {
            return nil
        }
        return Double(output[openBracket.upperBound ..< markerRange.lowerBound].trimmingCharacters(in: .whitespaces))
    }

    private func pruneDiskutilProgress(_ message: String) -> String {
        message
            .replacingOccurrences(of: "\\[\\s*\\d+(\\.\\d+)?% completed\\][ \\t]*", with: "", options: .regularExpression)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDdProgress(_ output: String) -> Int? {
        let lines = output.split(whereSeparator: { $0 == "\r" || $0 == "\n" })
        for line in lines.reversed() {
            let tokens = line.split(separator: " ")
            if tokens.count >= 2, tokens[1] == "bytes", let bytes = Int(tokens[0]) {
                return bytes
            }
        }
        return nil
    }
}
