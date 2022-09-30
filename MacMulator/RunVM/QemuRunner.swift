//
//  QemuRunner.swift
//  MacMulator
//
//  Created by Vale on 03/02/21.
//

import Cocoa

class QemuRunner : VirtualMachineRunner {
    
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

    func runVM(recoveryMode: Bool, uponCompletion callback: @escaping (VMExecutionResult, VirtualMachine) -> Void) {
        shell.runCommand(getQemuCommand(), virtualMachine.path, uponCompletion: { result in
            callback(VMExecutionResult(exitCode: result, error: self.getStandardError()), self.virtualMachine);
        });
    }
    
    func getManagedVM() -> VirtualMachine {
        return virtualMachine;
    }
    
    func getListenPort() -> Int32 {
        return listenPort;
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
                        let mediaType = setupMediaType(drive);
                        let path = setupPath(drive, virtualMachine);
                        
                        builder = builder.withDrive(file: path, format: drive.format, index: driveIndex, media: mediaType);
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
    
    fileprivate func setupMediaType(_ drive: VirtualDrive) -> String {
        var mediaType = drive.mediaType;
        if mediaType == QemuConstants.MEDIATYPE_OPENCORE {
            mediaType = QemuConstants.MEDIATYPE_DISK;
        }
        return mediaType;
    }
    
    fileprivate func setupPath(_ drive: VirtualDrive, _ vm: VirtualMachine) -> String {
        var path = drive.path;
        // if User selected Install xxx.app, we add the sffix to reach BasSystem.dmg
        if path.hasSuffix(".app") && vm.os == QemuConstants.OS_MAC {
            path = extendPathForMacOSInstaller(path, vm.subtype);
        }
        return path;
    }
    
    fileprivate func createBuilderForPPC() -> QemuCommandBuilder {
        let networkDevice = virtualMachine.networkDevice != nil ? virtualMachine.networkDevice! : Utils.getNetworkForSubType(virtualMachine.os, virtualMachine.subtype)
       
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withBios(QemuConstants.PC_BIOS)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withDisplay(virtualMachine.os == QemuConstants.OS_LINUX ? QemuConstants.DISPLAY_DEFAULT : nil)
            .withShowCursor(virtualMachine.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(sanitizeMachineTypeForPPC())
            .withMemory(virtualMachine.memory)
            .withGraphics(virtualMachine.displayResolution)
            .withAutoBoot(true)
            .withVgaEnabled(true)
            .withPortMappings(virtualMachine.portMappings)
            .withNetwork(name: "network-0", device: networkDevice);
    }
        
    fileprivate func createBuilderForPPC64() -> QemuCommandBuilder {
        let networkDevice = virtualMachine.networkDevice != nil ? virtualMachine.networkDevice! : Utils.getNetworkForSubType(virtualMachine.os, virtualMachine.subtype)
        
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withShowCursor(virtualMachine.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_PSERIES)
            .withMemory(virtualMachine.memory)
            .withGraphics(virtualMachine.displayResolution)
            .withAutoBoot(true)
            .withVgaEnabled(true)
            .withNetwork(name: "network-0", device: networkDevice);
    }
    
    fileprivate func createBuilderForI386() -> QemuCommandBuilder {
        let networkDevice = virtualMachine.networkDevice != nil ? virtualMachine.networkDevice! : Utils.getNetworkForSubType(virtualMachine.os, virtualMachine.subtype)
        
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
            .withPortMappings(virtualMachine.portMappings)
            .withDevice(QemuConstants.USB_KEYBOARD)
            .withDevice(QemuConstants.USB_TABLET)
            .withNetwork(name: "network-0", device: networkDevice);
    }

    fileprivate func createBuilderForX86_64() -> QemuCommandBuilder {
        let isNative = Utils.hostArchitecture() == QemuConstants.HOST_X86_64 && !Utils.isRunningInEmulation();
        let hvfConfigured = virtualMachine.hvf != nil ? virtualMachine.hvf! : Utils.getAccelForSubType(virtualMachine.os, virtualMachine.subtype);
        let networkDevice = virtualMachine.networkDevice != nil ? virtualMachine.networkDevice! : Utils.getNetworkForSubType(virtualMachine.os, virtualMachine.subtype)
        
        if (virtualMachine.os == QemuConstants.OS_MAC) {
            return createBuilderForMacGuestX86_64(isNative, hvfConfigured, networkDevice);
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
            .withAccel(isNative && hvfConfigured ? QemuConstants.ACCEL_HVF : nil)
            .withCpu(sanitizeCPUTypeForIntel(isNative && hvfConfigured))
            .withSound(QemuConstants.SOUND_HDA)
            .withSound(QemuConstants.SOUND_HDA_DUPLEX)
            .withUsb(true)
            .withPortMappings(virtualMachine.portMappings)
            .withDevice(QemuConstants.USB_KEYBOARD)
            .withDevice(QemuConstants.USB_TABLET);
    }
    
    fileprivate func createBuilderForMacGuestX86_64(_ isNative: Bool, _ hvfConfigured: Bool, _ networkDevice: String) -> QemuCommandBuilder {
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withBios(QemuConstants.PC_BIOS)
            .withCpu(Utils.getCpuTypeForSubType(virtualMachine.os, virtualMachine.subtype, isNative && hvfConfigured))
            .withCpus(virtualMachine.cpus)
            .withBootArg(QemuConstants.ARG_BOOTLOADER)
            .withMachine(QemuConstants.MACHINE_TYPE_Q35)
            .withMemory(virtualMachine.memory)
            .withVga(QemuConstants.VGA_VIRTIO)
            .withAccel(isNative && hvfConfigured ? QemuConstants.ACCEL_HVF : QemuConstants.ACCEL_TCG)
            .withSound(QemuConstants.SOUND_HDA)
            .withSound(QemuConstants.SOUND_HDA_DUPLEX)
            .withUsb(true)
            .withPortMappings(virtualMachine.portMappings)
            .withDevice(QemuConstants.USB_KEYBOARD)
            .withDevice(QemuConstants.USB_TABLET)
            .withDevice(QemuConstants.APPLE_SMC)
            .withNetwork(name: "network-0", device: networkDevice)
    }
    
    fileprivate func createBuilderForARM() -> QemuCommandBuilder {
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withSerial(QemuConstants.SERIAL_STDIO)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withShowCursor(virtualMachine.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_VERSATILEPB)
            .withCpu(sanitizeCPUTypeForARM())
            .withMemory(virtualMachine.memory);
    }

    fileprivate func createBuilderForARM64() -> QemuCommandBuilder {
        let isNative = Utils.hostArchitecture() == QemuConstants.HOST_ARM64 && !Utils.isRunningInEmulation();
        let hvfConfigured = virtualMachine.hvf != nil ? virtualMachine.hvf! : Utils.getAccelForSubType(virtualMachine.os, virtualMachine.subtype);
        
        return QemuCommandBuilder(qemuPath: virtualMachine.qemuPath != nil ? virtualMachine.qemuPath! : qemuPath, architecture: virtualMachine.architecture)
            .withSerial(QemuConstants.SERIAL_STDIO)
            .withCpus(virtualMachine.cpus)
            .withBootArg(computeBootArg(virtualMachine))
            .withShowCursor(virtualMachine.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_VIRT)
            .withCpu(sanitizeCPUTypeForARM64(isNative))
            .withMemory(virtualMachine.memory)
            .withDisplay(QemuConstants.DISPLAY_DEFAULT)
            .withDevice(QemuConstants.VIRTIO_GPU_PCI)
            .withAccel(isNative && hvfConfigured ? QemuConstants.ACCEL_HVF : nil)
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
            if drive.isBootDrive {
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
    
    fileprivate func sanitizeMachineTypeForPPC() -> String {
        var machineType = Utils.getMachineTypeForSubType(virtualMachine.os, virtualMachine.subtype);
        if (machineType != QemuConstants.MACHINE_TYPE_MAC99 && machineType != QemuConstants.MACHINE_TYPE_MAC99_PMU) {
            machineType = QemuConstants.MACHINE_TYPE_MAC99_PMU;
        }
        return machineType
    }
    
    fileprivate func sanitizeCPUTypeForIntel(_ isNative: Bool) -> String {
        var cpuType = Utils.getCpuTypeForSubType(virtualMachine.os, virtualMachine.subtype, isNative);
        if (cpuType != QemuConstants.CPU_HOST &&
            cpuType != QemuConstants.CPU_PENRYN &&
            cpuType != QemuConstants.CPU_PENRYN_SSE &&
            cpuType != QemuConstants.CPU_SANDY_BRIDGE &&
            cpuType != QemuConstants.CPU_IVY_BRIDGE &&
            cpuType != QemuConstants.CPU_QEMU64 ) {
            cpuType = QemuConstants.CPU_QEMU64;
        }
        return cpuType
    }
    
    fileprivate func sanitizeCPUTypeForARM() -> String {
        var cpuType = Utils.getCpuTypeForSubType(virtualMachine.os, virtualMachine.subtype, false);
        if (cpuType != QemuConstants.CPU_ARM1176 ) {
            cpuType = QemuConstants.CPU_ARM1176;
        }
        return cpuType
    }
    
    fileprivate func sanitizeCPUTypeForARM64(_ isNative: Bool) -> String {
        var cpuType = Utils.getCpuTypeForSubType(virtualMachine.os, virtualMachine.subtype, isNative);
        if (cpuType != QemuConstants.CPU_HOST &&
            cpuType != QemuConstants.CPU_CORTEX_A72 &&
            cpuType != QemuConstants.CPU_MAX) {
            cpuType = QemuConstants.CPU_CORTEX_A72;
        }
        return cpuType
    }
    
    fileprivate func extendPathForMacOSInstaller(_ path: String, _ subtype: String?) -> String {
        var installDMGFile: String = "";
        if (subtype == QemuConstants.SUB_MAC_LION ||
            subtype == QemuConstants.SUB_MAC_MOUNTAIN_LION ||
            subtype == QemuConstants.SUB_MAC_MAVERICKS ||
            subtype == QemuConstants.SUB_MAC_YOSEMITE ||
            subtype == QemuConstants.SUB_MAC_EL_CAPITAN ||
            subtype == QemuConstants.SUB_MAC_SIERRA) {
            installDMGFile = "/Contents/SharedSupport/InstallESD.dmg";
        } else {
            installDMGFile = "/Contents/SharedSupport/BaseSystem.dmg";
        }
        return path + installDMGFile;
    }
    
    func waitForCompletion() {
        shell.waitForCommand();
    }
    
    func isVMRunning() -> Bool {
        return shell.isRunning();
    }
    
    func stopVM() {
        shell.kill();
    }
    
    func pauseVM() {
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
