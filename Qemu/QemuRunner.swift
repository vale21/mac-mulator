//
//  QemuRunner.swift
//  MacMulator
//
//  Created by Vale on 03/02/21.
//

import Cocoa

class QemuRunner {
    
    let listenPort: Int32;
    let shell = Shell();
    let qemuPath: String;
    let virtualMachine: VirtualMachine;
    
    init(listenPort: Int32, virtualMachine: VirtualMachine) {
        qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        self.listenPort = listenPort;
        self.virtualMachine = virtualMachine;
    }

    func runVM(uponCompletion callback: @escaping (VirtualMachine) -> Void) {
        shell.runCommand(getQemuCommand(), uponCompletion: {
            callback(self.virtualMachine);
        });
    }
    
    func getQemuCommand() -> String {
        if let command = virtualMachine.qemuCommand {
            return command;
        } else {
            var builder: QemuCommandBuilder;
            if virtualMachine.os == QemuConstants.OS_MAC {
                builder =
                    QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
                    .withBios(QemuConstants.PC_BIOS)
                    .withCpus(virtualMachine.cpus)
                    .withBootArg(computeBootArg(virtualMachine))
                    .withMachine(QemuConstants.MACHINE_TYPE_MAC99)
                    .withMemory(virtualMachine.memory)
                    .withGraphics(virtualMachine.displayResolution)
                    .withAutoBoot(true)
                    .withVgaEnabled(true)
                    .withNetwork(name: "network-0", device: QemuConstants.NETWORK_SUNGEM);
            } else {
                builder =
                    QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
                    .withBios(QemuConstants.PC_BIOS)
                    .withCpus(virtualMachine.cpus)
                    .withBootArg(computeBootArg(virtualMachine))
                    .withMachine(QemuConstants.MACHINE_TYPE_Q35)
                    .withMemory(virtualMachine.memory)
                    .withVga(QemuConstants.VGA_VIRTIO)
                    .withCpu(QemuConstants.CPU_HOST)
                    .withAccel(QemuConstants.ACCEL_HVF)
                    .withUsb(QemuConstants.USB_TABLET);
            }
                
            var index = 1;
            for drive in virtualMachine.drives {
                if (driveExists(drive)) {
                    
                    var driveIndex = 0;
                    if !drive.isBootDrive {
                        driveIndex = index;
                        index += 1;
                    }
                    
                    builder = builder.withDrive(file: drive.path, format: drive.format, index: driveIndex, media: drive.mediaType);
                } else {
                    Utils.showPrompt(window: NSApp.mainWindow!, style: NSAlert.Style.warning, message: "Drive " + drive.path + " was not found. Do you want to remove it?", completionHandler: {
                                        response in if response.rawValue == Utils.ALERT_RESP_OK {
                                            self.virtualMachine.drives.remove(at: self.virtualMachine.drives.firstIndex(where: { vd in return vd.name == drive.name })!);
                                            self.virtualMachine.writeToPlist();
                                        }});
                }
            }
            
            builder = builder.withManagementPort(listenPort);
            return builder.build();
        }
    }
        
    fileprivate func computeBootArg(_ vm: VirtualMachine) -> String {
        
        if vm.qemuBootLoader {
            return QemuConstants.ARG_BOOTLOADER;
        }
        
        for drive in vm.drives {
            if drive.isBootDrive          {
                if drive.mediaType == QemuConstants.MEDIATYPE_DISK {
                    return QemuConstants.ARG_HD
                }
                if drive.mediaType == QemuConstants.MEDIATYPE_CDROM {
                    return QemuConstants.ARG_CD;
                }
            }
        }
         
        return QemuConstants.ARG_NET;
    }
    
    fileprivate func searchForDrive(_ vm: VirtualMachine, _ mediaType: String) -> Bool {
        for virtualDrive in vm.drives {
            if (virtualDrive.mediaType == mediaType) {
                return true;
            }
        }
        return false;
    }
    
    fileprivate func driveExists(_ drive: VirtualDrive) -> Bool {
        if (drive.mediaType == QemuConstants.MEDIATYPE_CDROM) {
            let filemanager = FileManager.default;
            return filemanager.fileExists(atPath: drive.path);
        }
        return true;
    }
    
    func waitForCompletion() {
        shell.waitForCommand();
    }
    
    func isRunning() -> Bool {
        return shell.isRunning();
    }
    
    func kill() {
        shell.kill();
    }
}
