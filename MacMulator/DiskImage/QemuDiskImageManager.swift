//
//  QemuDiskImageManager.swift
//  MacMulator
//
//  Created by Vale on 22/10/26.
//

import Foundation

class QemuDiskImageManager: DiskImageManager {
    func createDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32) -> Void) {
        createDiskImage(path: path, name: virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION, format: virtualDrive.format, size: String(virtualDrive.size) + "G", uponCompletion: callback)
    }

    private func createDiskImage(path: String, name: String, format: String, size: String, uponCompletion callback: @escaping (Int32) -> Void) {
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

    func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, uponCompletion callback: @escaping (Int32) -> Void) {
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

    func convertDiskImage(_ virtualDrive: VirtualDrive, _ path: String, fromFormat oldFormat: String, uponCompletion callback: @escaping (Int32) -> Void) {
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

        shell.runCommand(command, path, uponCompletion: { terminationCode in
            guard terminationCode == 0 else {
                print("Failed to convert disk image to " + format + ": " + shell.readFromConsole())
                try? FileManager.default.removeItem(atPath: tempPath)
                callback(terminationCode)
                return
            }

            do {
                _ = try FileManager.default.replaceItemAt(URL(fileURLWithPath: drivePath), withItemAt: URL(fileURLWithPath: tempPath))
                callback(0)
            } catch {
                print("Failed to replace disk image with converted " + format + " image: \(error)")
                try? FileManager.default.removeItem(atPath: tempPath)
                callback(-1)
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
            terminationCode in

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

        shell.runCommand(command, path, uponCompletion: { terminationCcode in
            callback(terminationCcode, shell.readFromStandardOutput())
        })
    }
}
