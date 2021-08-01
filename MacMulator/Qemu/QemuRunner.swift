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
    let livePreviewEnabled: Bool;
    let virtualMachine: VirtualMachine;
    
    init(listenPort: Int32, virtualMachine: VirtualMachine) {
        qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        livePreviewEnabled = UserDefaults.standard.bool(forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED);
        self.listenPort = listenPort;
        self.virtualMachine = virtualMachine;
    }

    func runVM(uponCompletion callback: @escaping (Int32, VirtualMachine) -> Void) {
        shell.runCommand(getQemuCommand(), uponCompletion: { terminationCcode in
            callback(terminationCcode, self.virtualMachine);
        });
    }
    
    func getQemuCommand() -> String {
        if let command = virtualMachine.qemuCommand {
            return command;
        } else {
            var builder: QemuCommandBuilder;
            if virtualMachine.architecture == QemuConstants.ARCH_PPC {
                builder = createBuilderForPPC();
            } else {
                builder = createBuilderForX86_64();
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
            if livePreviewEnabled {
                builder = builder.withQmpString(true);
                builder = builder.withManagementPort(listenPort);
            }
            return builder.build();
        }
    }
    
    fileprivate func createBuilderForPPC() -> QemuCommandBuilder {
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withBios(QemuConstants.PC_BIOS)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withMachine(QemuConstants.MACHINE_TYPE_MAC99)
            .withMemory(virtualMachine.memory)
            .withGraphics(virtualMachine.displayResolution)
            .withAutoBoot(true)
            .withVgaEnabled(true)
            .withNetwork(name: "network-0", device: QemuConstants.NETWORK_SUNGEM);
    }
    
    fileprivate func createBuilderForX86_64() -> QemuCommandBuilder {
        let isNativeIntel = Utils.hostArchitecture() == QemuConstants.HOST_X86_64 && !Utils.isRunningInEmulation();
        
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withBios(QemuConstants.PC_BIOS)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withMachine(QemuConstants.MACHINE_TYPE_Q35)
            .withMemory(virtualMachine.memory)
            .withVga(QemuConstants.VGA_VIRTIO)
            //.withCpu(isNativeIntel ? QemuConstants.CPU_HOST : nil)
            .withAccel(isNativeIntel ? QemuConstants.ACCEL_HVF : nil)
            .withSoundHw(QemuConstants.SOUNDHW_HDA)
            .withUsb(QemuConstants.USB_TABLET);
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
    
    func getStandardError() -> String {
        return shell.readFromStandardError();
    }
}
