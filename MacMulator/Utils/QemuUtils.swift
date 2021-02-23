//
//  QemuUtils.swift
//  MacMulator
//
//  Created by Vale on 18/02/21.
//

import Foundation

class QemuUtils {
    
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
                .withExtension(Utils.getExtension(virtualDrive.format))
                .build();
        shell.runCommand(command);
    }
    
}
