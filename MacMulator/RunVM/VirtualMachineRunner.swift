//
//  VirtualMachineRunner.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation

class VMExecutionResult {
    let exitCode: Int32
    let error: String?

    init(exitCode: Int32) {
        self.exitCode = exitCode
        error = nil
    }

    init(exitCode: Int32, error: String) {
        self.exitCode = exitCode
        self.error = error
    }
}

protocol VirtualMachineRunner {
    func getManagedVM() -> VirtualMachine

    func runVM(recoveryMode: Bool, uponCompletion callback: @escaping (VMExecutionResult, VirtualMachine) -> Void) throws

    func isVMRunning() -> Bool

    func stopVM(guestStopped: Bool, uponCompletion: (((any Error)?) -> Void)?)

    func stopVMGracefully()

    func pauseVM()

    func createVMSnapshot(_ underlyingHandler: ((VirtualMachineSnapshot?) -> Void)?) throws

    func deleteVMSnapshot(snapshot: VirtualMachineSnapshot) throws

    func restoreVMSnapshot(snapshot: VirtualMachineSnapshot, _ underlyingHandler: ((VirtualMachineSnapshot?) -> Void)?) throws

    func abort()

    func getConsoleOutput() -> String
}

extension VirtualMachineRunner {
    func createVMSnapshot() throws {
        try createVMSnapshot(nil)
    }

    func stopVM(guestStopped: Bool) {
        stopVM(guestStopped: guestStopped, uponCompletion: nil)
    }

    func deleteVMSnapshotFiles(snapshot: VirtualMachineSnapshot, managedVm: VirtualMachine) throws {
        let fileManager = FileManager.default

        var filePaths: [String] = snapshot.driveSnapshotPaths
        if let memorySnapshotPath = snapshot.memorySnapshotPath {
            filePaths.append(memorySnapshotPath)
        }
        if let screenshotPath = snapshot.screenshotPath {
            filePaths.append(screenshotPath)
        }

        for filePath in filePaths where fileManager.fileExists(atPath: filePath) {
            do {
                try fileManager.removeItem(atPath: filePath)
            } catch {
                NSLog("Snapshot: failed to delete file \(filePath): \(error.localizedDescription)")
                throw error
            }
        }

        let snapshotFolderURL = URL(fileURLWithPath: managedVm.path)
            .appendingPathComponent("Snapshots")
            .appendingPathComponent(String(snapshot.timestamp))
        if fileManager.fileExists(atPath: snapshotFolderURL.path) {
            do {
                try fileManager.removeItem(at: snapshotFolderURL)
            } catch {
                NSLog("Snapshot: failed to delete folder \(snapshotFolderURL.path): \(error.localizedDescription)")
                throw error
            }
        }
    }

    func copyVMSnapshotFiles(running: Bool, managedVm: VirtualMachine) throws -> VirtualMachineSnapshot {
        let saveFileURL = URL(fileURLWithPath: managedVm.path).appendingPathComponent(MacMulatorConstants.SAVE_FILE_NAME)
        let screenshotFileURL = URL(fileURLWithPath: managedVm.path).appendingPathComponent(MacMulatorConstants.SCREENSHOT_FILE_NAME)

        let currentMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let snapshotsFolderPath = URL(fileURLWithPath: managedVm.path + "/Snapshots")
        let currentSnapshotFolderPath = snapshotsFolderPath.appendingPathComponent(String(currentMillis))

        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: currentSnapshotFolderPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("Snapshot: failed to create directory \(currentSnapshotFolderPath.path): \(error.localizedDescription)")
        }

        let saveFileExists = fileManager.fileExists(atPath: saveFileURL.path)
        let screenshotExists = fileManager.fileExists(atPath: screenshotFileURL.path)

        if saveFileExists {
            let memorySnapshotURL = currentSnapshotFolderPath.appendingPathComponent(MacMulatorConstants.SAVE_FILE_NAME)
            do {
                if running {
                    try fileManager.moveItem(at: URL(fileURLWithPath: saveFileURL.path), to: memorySnapshotURL)
                } else {
                    // If VM is not running but save file exists it means that VM is paused
                    // We don't want to move the save file, but just to copy it
                    try fileManager.copyItem(at: URL(fileURLWithPath: saveFileURL.path), to: memorySnapshotURL)
                }
            } catch {
                NSLog("Snapshot: failed to move memory save file from \(saveFileURL.path) to \(memorySnapshotURL.path): \(error.localizedDescription)")
                throw error
            }
        }

        if screenshotExists {
            let screenshotSnapshotURL = currentSnapshotFolderPath.appendingPathComponent(MacMulatorConstants.SCREENSHOT_FILE_NAME)
            do {
                if running {
                    try fileManager.moveItem(at: URL(fileURLWithPath: screenshotFileURL.path), to: screenshotSnapshotURL)
                } else {
                    // If VM is not running but screenshot exists it means that VM is paused
                    // We don't want to move the screenshot, but just to copy it
                    try fileManager.copyItem(at: URL(fileURLWithPath: screenshotFileURL.path), to: screenshotSnapshotURL)
                }
            } catch {
                NSLog("Snapshot: failed to move screenshot from \(screenshotFileURL.path) to \(screenshotSnapshotURL.path): \(error.localizedDescription)")
                throw error
            }
        }

        var drivePaths: [String] = []
        for drive in managedVm.drives {
            if drive.mediaType == QemuConstants.MEDIATYPE_DISK || drive.mediaType == QemuConstants.MEDIATYPE_NVME {
                let driveSnapshotURL = currentSnapshotFolderPath.appendingPathComponent(drive.name + "." + MacMulatorConstants.DISK_EXTENSION)
                do {
                    try fileManager.copyItem(at: URL(fileURLWithPath: drive.path), to: driveSnapshotURL)
                } catch {
                    NSLog("Snapshot: failed to copy drive \(drive.name) from \(drive.path) to \(driveSnapshotURL.path): \(error.localizedDescription)")
                    throw error
                }
                drivePaths.append(driveSnapshotURL.path)
            }
        }
        let snapshot = VirtualMachineSnapshot(timestamp: currentMillis,
                                              name: "",
                                              description: String(format: NSLocalizedString("VirtualMachineRunner.snapshotTaken", comment: ""), Date().formatted()),
                                              driveSnapshotPaths: drivePaths,
                                              memorySnapshotPath: saveFileExists ? currentSnapshotFolderPath.appendingPathComponent(MacMulatorConstants.SAVE_FILE_NAME).path : nil,
                                              screenshotPath: screenshotExists ? currentSnapshotFolderPath.appendingPathComponent(MacMulatorConstants.SCREENSHOT_FILE_NAME).path : nil,
                                              running: running)
        managedVm.addSnapshot(snapshot)
        managedVm.writeToPlist()
        return snapshot
    }

    func restoreVMSnapshotFiles(snapshot: VirtualMachineSnapshot, managedVm: VirtualMachine) throws {
        let saveFileURL = URL(fileURLWithPath: managedVm.path).appendingPathComponent(MacMulatorConstants.SAVE_FILE_NAME)
        let screenshotFileURL = URL(fileURLWithPath: managedVm.path).appendingPathComponent(MacMulatorConstants.SCREENSHOT_FILE_NAME)
        let fileManager = FileManager.default

        if let memorySnapshotPath = snapshot.memorySnapshotPath {
            do {
                try? fileManager.removeItem(at: URL(fileURLWithPath: saveFileURL.path))
                try fileManager.copyItem(at: URL(fileURLWithPath: memorySnapshotPath), to: URL(fileURLWithPath: saveFileURL.path))
            } catch {
                NSLog("Snapshot: failed to move save file \(memorySnapshotPath): \(error.localizedDescription)")
            }
        }
        if let screenshotPath = snapshot.screenshotPath {
            do {
                try? fileManager.removeItem(at: URL(fileURLWithPath: screenshotFileURL.path))
                try fileManager.copyItem(at: URL(fileURLWithPath: screenshotPath), to: URL(fileURLWithPath: screenshotFileURL.path))
            } catch {
                NSLog("Snapshot: failed to move save file \(screenshotPath): \(error.localizedDescription)")
            }
        }
        for drivePath in snapshot.driveSnapshotPaths {
            do {
                let destDrivePath = URL(fileURLWithPath: managedVm.path).appendingPathComponent(URL(fileURLWithPath: drivePath).lastPathComponent)
                try fileManager.removeItem(at: destDrivePath)
                try fileManager.copyItem(at: URL(fileURLWithPath: drivePath), to: destDrivePath)
            } catch {
                NSLog("Snapshot: failed to move disk file \(drivePath): \(error.localizedDescription)")
            }
        }
    }
}
