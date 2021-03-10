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
    
    static func createDiskImage(path: String, virtualDrive: VirtualDrive) {
        let qemuPath = UserDefaults.standard.string(forKey: "qemuPath") ?? "";
        let shell = Shell();
        
        shell.setWorkingDir(path);
        
        let command: String =
            QemuImgCommandBuilder(qemuPath:qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CREATE)
                .withFormat(virtualDrive.format)
                .withSize(virtualDrive.size)
                .withName(virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION)
                .build();
        
        shell.runCommand(command);
    }
    
    static func resizeDiskImage(_ virtualDrive: VirtualDrive, shrink: Bool) {
        let qemuPath = UserDefaults.standard.string(forKey: "qemuPath") ?? "";
        let shell = Shell();

        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_RESIZE)
            .withName(virtualDrive.path)
            .withShrinkArg(shrink)
            .withShortSize(virtualDrive.size)
            .build();
        
        shell.runCommand(command);
    }
    
    static func convertDiskImage(_ virtualDrive: VirtualDrive, oldFormat: String) {
        let qemuPath = UserDefaults.standard.string(forKey: "qemuPath") ?? "";
        let shell = Shell();

        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CONVERT)
            .withFormat(oldFormat)
            .withTargetFormat(virtualDrive.format)
            .withName(virtualDrive.path)
            .withTargetName(virtualDrive.path)
            .build();
        
        shell.runCommand(command);
    }
    
    static func updateDiskImage(oldVirtualDrive: VirtualDrive, newVirtualDrive: VirtualDrive) {
        if newVirtualDrive.size != oldVirtualDrive.size {
            resizeDiskImage(newVirtualDrive, shrink: (newVirtualDrive.size < oldVirtualDrive.size));
        }
        if newVirtualDrive.format != oldVirtualDrive.format {
            convertDiskImage(newVirtualDrive, oldFormat: oldVirtualDrive.format);
        }
    }
    
    static func getDiskImageInfo(_ virtualDrive: VirtualDrive) -> String {
        let qemuPath = UserDefaults.standard.string(forKey: "qemuPath") ?? "";
        let shell = Shell();

        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_INFO)
            .withName(virtualDrive.path)
            .build();
        
        return shell.runCommand(command);
    }
    
    
}
