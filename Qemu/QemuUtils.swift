//
//  QemuUtils.swift
//  MacMulator
//
//  Created by Vale on 18/02/21.
//

import Foundation

class QemuUtils {
    
    static func getDriveFormatDescription(_ format: String) -> String {
        return format == QemuConstants.FORMAT_RAW ? "(Plain data)" : "(Qemu Copy On Write format)"
    }
    
    static func getDriveTypeDescription(_ driveType: String) -> String {
        return driveType == QemuConstants.MEDIATYPE_CDROM ? QemuConstants.CD : QemuConstants.HD;
    }
    
    static func createDiskImage(path: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping () -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        shell.setWorkingDir(path);
        
        let command: String =
            QemuImgCommandBuilder(qemuPath:qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CREATE)
            .withFormat(virtualDrive.format)
            .withSize(virtualDrive.size)
            .withName(virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION)
            .build();
        
        shell.runCommand(command, uponCompletion: callback);
    }
    
    static func resizeDiskImage(_ virtualDrive: VirtualDrive, shrink: Bool, uponCompletion callback: @escaping () -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_RESIZE)
            .withName(virtualDrive.path)
            .withShrinkArg(shrink)
            .withShortSize(virtualDrive.size)
            .build();
        
        shell.runCommand(command, uponCompletion: callback);
    }
    
    static func convertDiskImage(_ virtualDrive: VirtualDrive, oldFormat: String, uponCompletion callback: @escaping () -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CONVERT)
            .withFormat(oldFormat)
            .withTargetFormat(virtualDrive.format)
            .withName(virtualDrive.path)
            .withTargetName(virtualDrive.path)
            .build();
        
        shell.runCommand(command, uponCompletion: callback);
    }
    
    static func updateDiskImage(oldVirtualDrive: VirtualDrive, newVirtualDrive: VirtualDrive, uponCompletion callback: @escaping () -> Void) {
        if newVirtualDrive.size != oldVirtualDrive.size {
            resizeDiskImage(newVirtualDrive, shrink: (newVirtualDrive.size < oldVirtualDrive.size), uponCompletion: callback);
        }
        if newVirtualDrive.format != oldVirtualDrive.format {
            convertDiskImage(newVirtualDrive, oldFormat: oldVirtualDrive.format, uponCompletion: callback);
        }
    }
    
    static func getDiskImageInfo(_ virtualDrive: VirtualDrive, uponCompletion callback: @escaping (String) -> Void) -> Void {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_INFO)
            .withName(virtualDrive.path)
            .build();
        
        shell.runCommand(command, uponCompletion: {
            callback(shell.getStandardOutput());
        });
    }
    
    static func isBinaryAvailable(_ binary: String) -> Bool {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let fileManager = FileManager.default;
        
        return fileManager.fileExists(atPath: qemuPath + "/" + binary);
    }
}
