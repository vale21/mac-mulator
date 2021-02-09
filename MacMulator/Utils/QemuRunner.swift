//
//  QemuRunner.swift
//  MacMulator
//
//  Created by Vale on 03/02/21.
//

import Cocoa

class QemuRunner {
    
    var listenPort: Int32 = 4444;
    let shell = Shell();
    let qemuPath: String;
    
    init() {
        qemuPath = UserDefaults.standard.string(forKey: "qemuPath") ?? "";
    }
    
    func createDiskImage(path: String, virtualDrive: VirtualDrive) {
        shell.setWorkingDir(path);
        
        let command: String =
            QemuImgCommandBuilder(qemuPath:qemuPath)
            .withCommand(QemuConstants.ImgCommands.Create.rawValue)
                .withFormat(virtualDrive.format)
                .withSize(virtualDrive.size)
                .withName(virtualDrive.name)
                .withExtension(QemuConstants.ImgTypes.Qcow2.rawValue)
                .build();
        shell.runCommand(command);
    }
    
    func runVM(virtualMachine: VirtualMachine, uponCompletion callback: @escaping (VirtualMachine) -> Void) {
        var builder: QemuCommandBuilder =
            QemuCommandBuilder(qemuPath: qemuPath)
            .withBios(QemuConstants.BiosTypes.Pc_bios.rawValue)
            .withBootArg(virtualMachine.bootArg)
            .withMachine(QemuConstants.MachineTypes.Mac99_pmu.rawValue)
            .withMemory(virtualMachine.memory)
            .withGraphics(virtualMachine.displayResolution)
            .withAutoBoot(true)
            .withVgaEnabled(true);
            
        for drive in virtualMachine.drives {
            if (driveExists(drive)) {
                builder = builder.withDrive(file: drive.path, format: drive.format, media: drive.mediaType);
            } else {
                Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.warning, message: "Drive " + drive.path + " was not found.");
            }
        }

        builder = builder
            .withNetwork(name: "network-0", device: QemuConstants.NetworkTypes.Sungem.rawValue)
            .withManagementPort(listenPort);

        shell.runAsyncCommand(builder.build(), uponCompletion: {
            callback(virtualMachine);
        });
        
        if (virtualMachine.isNew) {
            virtualMachine.isNew = false;
            virtualMachine.bootArg = QemuConstants.BootArgs.HD.rawValue;
            virtualMachine.writeToPlist();
        }
    }
    
    func driveExists(_ drive: VirtualDrive) -> Bool {
        if (drive.mediaType == QemuConstants.MediaTypes.CdRom.rawValue) {
            let filemanager = FileManager.default;
            return filemanager.fileExists(atPath: drive.path);
        }
        return true;
    }
    
    func setListenPort(_ listenPort: Int32) {
        self.listenPort = listenPort;
    }
    
    func waitForCompletion() {
        shell.waitForCommand();
    }
    
    func isRunning() -> Bool {
        return shell.isRunning();
    }
}
