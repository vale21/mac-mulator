//
//  QemuUtils.swift
//  MacMulator
//
//  Created by Vale on 18/02/21.
//

import Foundation

class QemuUtils {
    
    static func getExtension(_ format: String) -> String {
        return format == QemuConstants.FORMAT_RAW ? QemuConstants.EXTENSION_ISO : QemuConstants.EXTENSION_QCOW2;
    }
    
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
                .withName(virtualDrive.name)
                .withExtension(getExtension(virtualDrive.format))
                .build();
        shell.runCommand(command);
    }
    
    static func updateDiskImage(_ virtualDrive: VirtualDrive) {
        
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
