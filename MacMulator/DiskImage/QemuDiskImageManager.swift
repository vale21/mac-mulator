//
//  QemuDiskImageManager.swift
//  MacMulator
//
//  Created by Vale on 22/10/26.
//

import Foundation

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

    func flattenLinkedDiskImage(_ virtualDrive: VirtualDrive, _: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        DiskImageConverter().convert(virtualDrive, from: virtualDrive.format, uponCompletion: callback)
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
