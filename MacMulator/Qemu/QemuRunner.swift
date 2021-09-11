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
        shell.runCommand(getQemuCommand(), virtualMachine.path, uponCompletion: { terminationCcode in
            callback(terminationCcode, self.virtualMachine);
        });
    }
    
    func getQemuCommand() -> String {
        if let command = virtualMachine.qemuCommand {
            return command;
        } else {
            var builder: QemuCommandBuilder;
            
            switch virtualMachine.architecture {
            case QemuConstants.ARCH_PPC:
                builder = createBuilderForPPC();
                break;
            case QemuConstants.ARCH_PPC64:
                builder = createBuilderForPPC64();
                break;
            case QemuConstants.ARCH_X86:
                builder = createBuilderForI386();
                break;
            case QemuConstants.ARCH_X64:
                builder = createBuilderForX86_64();
                break;
            case QemuConstants.ARCH_ARM:
                builder = createBuilderForARM();
                break;
            case QemuConstants.ARCH_ARM64:
                builder = createBuilderForARM64();
                break;
            case QemuConstants.ARCH_68K:
                builder = createBuilderForM68k();
                break;
            default:
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
                    
                    if drive.mediaType == QemuConstants.MEDIATYPE_EFI {
                        builder = builder.withEfi(file: drive.path);
                    } else {
                        var mediaType = drive.mediaType;
                        if mediaType == QemuConstants.MEDIATYPE_OPENCORE {
                            mediaType = QemuConstants.MEDIATYPE_DISK;
                        }
                        builder = builder.withDrive(file: drive.path, format: drive.format, index: driveIndex, media: mediaType);
                    }
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
            .withDisplay(virtualMachine.os == QemuConstants.OS_LINUX ? QemuConstants.DISPLAY_DEFAULT : nil)
            .withShowCursor(virtualMachine.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(Utils.getMachineTypeForSubType(virtualMachine.os, virtualMachine.subtype ?? Utils.getSubType(virtualMachine.os, 0)))
            .withMemory(virtualMachine.memory)
            .withGraphics(virtualMachine.displayResolution)
            .withAutoBoot(true)
            .withVgaEnabled(true)
            .withNetwork(name: "network-0", device: QemuConstants.NETWORK_SUNGEM);
    }
    
    fileprivate func createBuilderForPPC64() -> QemuCommandBuilder {
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withShowCursor(virtualMachine.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_PSERIES)
            .withMemory(virtualMachine.memory)
            .withGraphics(virtualMachine.displayResolution)
            .withAutoBoot(true)
            .withVgaEnabled(true)
            .withNetwork(name: "network-0", device: QemuConstants.NETWORK_SUNGEM);
    }
    
    fileprivate func createBuilderForI386() -> QemuCommandBuilder {
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withBios(QemuConstants.PC_BIOS)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withDisplay(virtualMachine.os == QemuConstants.OS_LINUX ? QemuConstants.DISPLAY_DEFAULT : nil)
            .withShowCursor(virtualMachine.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_PC)
            .withMemory(virtualMachine.memory)
            .withVga(QemuConstants.VGA_VIRTIO)
            .withSound(QemuConstants.SOUND_AC97)
            .withUsb(true)
            .withDevice(QemuConstants.USB_KEYBOARD)
            .withDevice(QemuConstants.USB_TABLET)
            .withNetwork(name: "network-0", device: QemuConstants.NETWORK_VIRTIO);
    }

    fileprivate func createBuilderForX86_64() -> QemuCommandBuilder {
        let isNative = Utils.hostArchitecture() == QemuConstants.HOST_X86_64 && !Utils.isRunningInEmulation();
        if (virtualMachine.os == QemuConstants.OS_MAC) {
            return createBuilderForMacGuestX86_64(isNative);
        }
    
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withBios(QemuConstants.PC_BIOS)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withDisplay(virtualMachine.os == QemuConstants.OS_LINUX ? QemuConstants.DISPLAY_DEFAULT : nil)
            .withShowCursor(virtualMachine.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_Q35)
            .withMemory(virtualMachine.memory)
            .withVga(QemuConstants.VGA_VIRTIO)
            .withAccel(isNative ? QemuConstants.ACCEL_HVF : nil)
            .withSound(QemuConstants.SOUND_HDA)
            .withSound(QemuConstants.SOUND_HDA_DUPLEX)
            .withUsb(true)
            .withDevice(QemuConstants.USB_KEYBOARD)
            .withDevice(QemuConstants.USB_TABLET);
    }
    
    fileprivate func createBuilderForMacGuestX86_64(_ isNative: Bool) -> QemuCommandBuilder {
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withBios(QemuConstants.PC_BIOS)
            .withCpu(isNative ? QemuConstants.CPU_HOST : QemuConstants.CPU_PERYN)
            .withCpus(virtualMachine.cpus)
            .withBootArg(QemuConstants.ARG_BOOTLOADER)
            .withMachine(QemuConstants.MACHINE_TYPE_Q35)
            .withMemory(virtualMachine.memory)
            .withVga(QemuConstants.VGA_VIRTIO)
            .withAccel(isNative ? QemuConstants.ACCEL_HVF : nil)
            .withSound(QemuConstants.SOUND_HDA)
            .withSound(QemuConstants.SOUND_HDA_DUPLEX)
            .withUsb(true)
            .withDevice(QemuConstants.USB_KEYBOARD)
            .withDevice(QemuConstants.USB_TABLET)
            .withDevice(QemuConstants.APPLE_SMC)
            .withNetwork(name: "network-0", device: QemuConstants.NETWORK_VMXNET)
    }
    
    fileprivate func createBuilderForARM() -> QemuCommandBuilder {
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withSerial(QemuConstants.SERIAL_STDIO)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withShowCursor(virtualMachine.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_VERSATILEPB)
            .withCpu(QemuConstants.CPU_ARM1176)
            .withMemory(virtualMachine.memory);
    }

    fileprivate func createBuilderForARM64() -> QemuCommandBuilder {
        let isNative = Utils.hostArchitecture() == QemuConstants.HOST_ARM64 && !Utils.isRunningInEmulation();
        
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withSerial(QemuConstants.SERIAL_STDIO)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withShowCursor(virtualMachine.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_VIRT)
            .withCpu(QemuConstants.CPU_CORTEX_A72)
            .withMemory(virtualMachine.memory)
            .withDisplay(QemuConstants.DISPLAY_DEFAULT)
            .withDevice(QemuConstants.VIRTIO_GPU_PCI)
            .withAccel(isNative ? QemuConstants.ACCEL_HVF : nil)
            .withSound(QemuConstants.SOUND_HDA)
            .withSound(QemuConstants.SOUND_HDA_DUPLEX)
            .withDevice(QemuConstants.QEMU_XHCI)
            .withDevice(QemuConstants.USB_KEYBOARD)
            .withDevice(QemuConstants.USB_TABLET);
    }

    fileprivate func createBuilderForM68k() -> QemuCommandBuilder {
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withShowCursor(virtualMachine.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_Q800)
            .withMemory(virtualMachine.memory);
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
    
    func getStandardOutput() -> String {
        return shell.readFromStandardOutput();
    }
    
    func getConsoleOutput() -> String {
        return shell.readFromConsole();
    }
}
