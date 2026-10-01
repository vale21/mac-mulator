//
//  QemuRunner.swift
//  MacMulator
//
//  Created by Vale on 03/02/21.
//

import Cocoa
import Virtualization

class QemuRunner: VirtualMachineRunner {
    let listenPort: Int32
    let shell = Shell()
    let qemuPath: String
    let livePreviewEnabled: Bool
    let managedVm: VirtualMachine

    init(listenPort: Int32, virtualMachine: VirtualMachine) {
        qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!
        livePreviewEnabled = UserDefaults.standard.bool(forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED)
        self.listenPort = listenPort
        managedVm = virtualMachine
    }

    func runVM(recoveryMode _: Bool, uponCompletion callback: @escaping (VMExecutionResult, VirtualMachine) -> Void) throws {
        let command = getQemuCommand()
        do {
            try QemuRunner.validateQemuCommand(command: command, globalQemuPath: qemuPath, configuredQemuPath: managedVm.qemuPath) {
                validationResult, error in
                if validationResult {
                    self.shell.runCommand(command, self.managedVm.path, uponCompletion: { result in
                        callback(VMExecutionResult(exitCode: result, error: self.getStandardError()), self.managedVm)
                    })
                } else {
                    callback(VMExecutionResult(exitCode: -1, error: error!.description), self.managedVm)
                }
            }
        } catch {
            throw error
        }
    }

    func getManagedVM() -> VirtualMachine {
        managedVm
    }

    func getListenPort() -> Int32 {
        listenPort
    }

    func createVMSnapshot(_ underlyingHandler: ((VirtualMachineSnapshot?) -> Void)? = nil) throws {
        if isVMRunning() {
            throw ValidationError.snapshotError(vmType: "QEMU")
        }

        let snapshot = try? copyVMSnapshotFiles(running: false, managedVm: managedVm)
        if let underlyingHandler {
            underlyingHandler(snapshot)
        }
    }

    func deleteVMSnapshot(snapshot: VirtualMachineSnapshot) throws {
        managedVm.removeSnapshot(snapshot.timestamp)
        try deleteVMSnapshotFiles(snapshot: snapshot, managedVm: managedVm)
    }

    func restoreVMSnapshot(snapshot: VirtualMachineSnapshot, _ underlyingHandler: ((VirtualMachineSnapshot?) -> Void)? = nil) throws {
        if isVMRunning() {
            throw ValidationError.snapshotError(vmType: "QEMU")
        }

        try? restoreVMSnapshotFiles(snapshot: snapshot, managedVm: managedVm)
        if let underlyingHandler {
            underlyingHandler(snapshot)
        }
    }

    func getQemuCommand() -> String {
        if let command = managedVm.qemuCommand {
            return command
        } else {
            var builder: QemuCommandBuilder = switch managedVm.architecture {
            case QemuConstants.ARCH_PPC:
                createBuilderForPPC()
            case QemuConstants.ARCH_PPC64:
                createBuilderForPPC64()
            case QemuConstants.ARCH_X86:
                createBuilderForI386()
            case QemuConstants.ARCH_X64:
                createBuilderForX86_64()
            case QemuConstants.ARCH_ARM:
                createBuilderForARM()
            case QemuConstants.ARCH_ARM64:
                createBuilderForARM64()
            case QemuConstants.ARCH_68K:
                createBuilderForM68k()
            default:
                createBuilderForX86_64()
            }

            var index = 1
            Utils.removeUnexistingDrives(managedVm)
            Utils.sortDrives(managedVm)

            if managedVm.os != QemuConstants.OS_IOS { // iOS has no drives, but uses the NAND
                for drive in managedVm.drives {
                    var driveIndex = 0
                    if !drive.isBootDrive {
                        driveIndex = index
                        index += 1
                    }

                    if drive.mediaType == QemuConstants.MEDIATYPE_EFI {
                        builder = builder.withEfi(file: drive.path)
                    } else if drive.mediaType == QemuConstants.MEDIATYPE_EFI_SECURE {
                        builder = builder.withEfiSecure(file: drive.path)
                    } else if drive.mediaType == QemuConstants.MEDIATYPE_EFI_VARS || drive.mediaType == QemuConstants.MEDIATYPE_EFI_SECURE_VARS {
                        builder = builder.withEfiVars(file: drive.path, global: false)
                    } else {
                        let mediaType = setupMediaType(managedVm.subtype, drive)
                        let path = setupPath(drive, managedVm)

                        builder = builder.withDrive(file: path, format: drive.format, index: driveIndex, media: mediaType)
                    }
                }
                if livePreviewEnabled {
                    builder = builder.withQmpString(true)
                    builder = builder.withManagementPort(listenPort)
                }
            }
            return builder.build()
        }
    }

    static func validateQemuCommand(command: String, globalQemuPath: String, configuredQemuPath: String?, uponCompletion callback: @escaping (Bool, ValidationError?) -> Void) throws {
        if command.starts(with: "sudo") {
            throw ValidationError.sudoNotAllowed
        }

        let qemuPath = configuredQemuPath != nil ? configuredQemuPath! : globalQemuPath
        if !command.starts(with: qemuPath) {
            throw ValidationError.workingPathError(qemuPath: qemuPath, command: command)
        }

        let allowedExecutables: [String] = [
            String(qemuPath + "/" + QemuConstants.ARCH_PPC),
            String(qemuPath + "/" + QemuConstants.ARCH_PPC64),
            String(qemuPath + "/" + QemuConstants.ARCH_X86),
            String(qemuPath + "/" + QemuConstants.ARCH_X64),
            String(qemuPath + "/" + QemuConstants.ARCH_ARM),
            String(qemuPath + "/" + QemuConstants.ARCH_ARM64),
            String(qemuPath + "/" + QemuConstants.ARCH_68K),
            String(qemuPath + "/" + QemuConstants.ARCH_RISCV32),
            String(qemuPath + "/" + QemuConstants.ARCH_RISCV64),
        ]

        var matched = false
        for executable in allowedExecutables {
            if command.starts(with: executable) {
                matched = true
                break
            }
        }

        if !matched {
            throw ValidationError.executableError(allowed: allowedExecutables.joined(separator: ",\n"), command: command)
        }

        QemuUtils.getQemuVersion(qemuPath: qemuPath, uponCompletion: {
            version in
            if let version {
                let versionRegexp = try! NSRegularExpression(pattern: "\\d+\\.\\d+\\.\\d+")
                let range = NSRange(location: 0, length: version.utf16.count)
                if versionRegexp.firstMatch(in: version, range: range) != nil {
                    callback(true, nil)
                } else {
                    callback(false, ValidationError.genericError)
                    print("Received version: " + version)
                }
            } else {
                callback(false, ValidationError.genericError)
                print("Received no version.")
            }
        })
    }

    fileprivate func setupMediaType(_ subtype: String, _ drive: VirtualDrive) -> String {
        var mediaType = drive.mediaType
        if mediaType == QemuConstants.MEDIATYPE_OPENCORE {
            mediaType = subtype == QemuConstants.SUB_WINDOWS_11 ? QemuConstants.MEDIATYPE_NVME : QemuConstants.MEDIATYPE_DISK
        }
        return mediaType
    }

    fileprivate func setupPath(_ drive: VirtualDrive, _ vm: VirtualMachine) -> String {
        var path = drive.path
        // if User selected Install xxx.app, we add the sffix to reach BasSystem.dmg
        if path.hasSuffix(".app"), vm.os == QemuConstants.OS_MAC {
            path = extendPathForMacOSInstaller(path, vm.subtype)
        }
        return path
    }

    fileprivate func createBuilderForPPC() -> QemuCommandBuilder {
        let networkDevice = managedVm.networkDevice != nil ? managedVm.networkDevice! : Utils.getNetworkForSubType(managedVm.os, managedVm.subtype, managedVm.architecture)

        return QemuCommandBuilder(qemuPath: managedVm.qemuPath != nil ? managedVm.qemuPath! : qemuPath, architecture: managedVm.architecture)
            .withBios(QemuConstants.PC_BIOS)
            .withCpus(managedVm.cpus)
            .withBootArg(computeBootArg(managedVm))
            .withShowCursor(managedVm.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(sanitizeMachineTypeForPPC(), [])
            .withMemory(managedVm.memory)
            .withGraphics(managedVm.displayResolution)
            .withAutoBoot(true)
            .withVgaEnabled(true)
            .withPortMappings(managedVm.portMappings)
            .withNetwork(name: "network-0", device: networkDevice, macAddress: managedVm.macAddress)
    }

    fileprivate func createBuilderForPPC64() -> QemuCommandBuilder {
        let networkDevice = managedVm.networkDevice != nil ? managedVm.networkDevice! : Utils.getNetworkForSubType(managedVm.os, managedVm.subtype, managedVm.architecture)

        return QemuCommandBuilder(qemuPath: managedVm.qemuPath != nil ? managedVm.qemuPath! : qemuPath, architecture: managedVm.architecture)
            .withCpus(managedVm.cpus)
            .withBootArg(computeBootArg(managedVm))
            .withShowCursor(managedVm.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_PSERIES, [])
            .withMemory(managedVm.memory)
            .withGraphics(managedVm.displayResolution)
            .withAutoBoot(true)
            .withVgaEnabled(true)
            .withNetwork(name: "network-0", device: networkDevice, macAddress: managedVm.macAddress)
    }

    fileprivate func createBuilderForI386() -> QemuCommandBuilder {
        let networkDevice = managedVm.networkDevice != nil ? managedVm.networkDevice! : Utils.getNetworkForSubType(managedVm.os, managedVm.subtype, managedVm.architecture)

        return QemuCommandBuilder(qemuPath: managedVm.qemuPath != nil ? managedVm.qemuPath! : qemuPath, architecture: managedVm.architecture)
            .withBios(QemuConstants.PC_BIOS)
            .withCpus(managedVm.cpus)
            .withBootArg(computeBootArg(managedVm))
            .withShowCursor(managedVm.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_PC, [])
            .withMemory(managedVm.memory)
            .withVga(QemuConstants.VGA_VIRTIO)
            .withSound(QemuConstants.SOUND_AC97)
            .withUsb(true)
            .withPortMappings(managedVm.portMappings)
            .withDevice(QemuConstants.USB_KEYBOARD)
            .withDevice(QemuConstants.USB_TABLET)
            .withNetwork(name: "network-0", device: networkDevice, macAddress: managedVm.macAddress)
    }

    fileprivate func createBuilderForX86_64() -> QemuCommandBuilder {
        let isNative = Utils.hostArchitecture() == QemuConstants.HOST_X86_64 && !Utils.isRunningInEmulation()
        let hvfConfigured = managedVm.hvf != nil ? managedVm.hvf! : Utils.getAccelForSubType(managedVm.os, managedVm.subtype)
        let networkDevice = managedVm.networkDevice != nil ? managedVm.networkDevice! : Utils.getNetworkForSubType(managedVm.os, managedVm.subtype, managedVm.architecture)
        var videoDevice = managedVm.videoDevice != nil ? managedVm.videoDevice! : Utils.getVideoForSubType(managedVm.os, managedVm.subtype)
        if managedVm.enable3DAcceleration ?? false {
            videoDevice = Utils.convertDeviceToGLVariant(videoDevice)
        }

        if managedVm.os == QemuConstants.OS_MAC {
            return createBuilderForMacGuestX86_64(isNative, hvfConfigured, networkDevice, videoDevice)
        }

        var builder = QemuCommandBuilder(qemuPath: managedVm.qemuPath != nil ? managedVm.qemuPath! : qemuPath, architecture: managedVm.architecture)
            .withBios(QemuConstants.PC_BIOS)
            .withCpus(managedVm.cpus)
            .withBootArg(computeBootArg(managedVm))
            .withDisplay(managedVm.qemuDisplay)
            .withEnable3D(managedVm.enable3DAcceleration ?? true)
            .withShowCursor(false)
            .withMachine(QemuConstants.MACHINE_TYPE_Q35, [])
            .withMemory(managedVm.memory)
            .withVga(videoDevice)
            .withAccel(isNative && hvfConfigured ? QemuConstants.ACCEL_HVF : nil)
            .withCpu(sanitizeCPUTypeForIntel(isNative && hvfConfigured))
            .withUsb(true)
            .withPortMappings(managedVm.portMappings)
            .withDevice(QemuConstants.USB_KEYBOARD)
            .withDevice(QemuConstants.USB_TABLET)
            .withNetwork(name: "network-0", device: networkDevice, macAddress: managedVm.macAddress)
            .withTpm(Utils.getTPMForSubType(managedVm.os, managedVm.subtype) ? managedVm.path : nil, QemuConstants.TPM_TIS)
        let sound = Utils.getSoundForSubType(managedVm.os, managedVm.subtype)
        if sound == QemuConstants.SOUND_HDA {
            builder = builder.withSound(QemuConstants.SOUND_HDA).withSound(QemuConstants.SOUND_HDA_DUPLEX)
        } else {
            builder = builder.withSound(sound)
        }
        return builder
    }

    fileprivate func createBuilderForMacGuestX86_64(_ isNative: Bool, _ hvfConfigured: Bool, _ networkDevice: String, _ videoDevice: String) -> QemuCommandBuilder {
        QemuCommandBuilder(qemuPath: managedVm.qemuPath != nil ? managedVm.qemuPath! : qemuPath, architecture: managedVm.architecture)
            .withBios(QemuConstants.PC_BIOS)
            .withCpu(Utils.getCpuTypeForSubType(managedVm.os, managedVm.subtype, isNative && hvfConfigured))
            .withCpus(managedVm.cpus)
            .withBootArg(QemuConstants.ARG_BOOTLOADER)
            .withMachine(QemuConstants.MACHINE_TYPE_Q35, [])
            .withMemory(managedVm.memory)
            .withVga((managedVm.enable3DAcceleration ?? true) ? Utils.buildParavirtualizedVgaString(displayResolution: managedVm.displayResolution) : videoDevice)
            .withDisplay(managedVm.qemuDisplay)
            .withEnableAppleParavirtualizedGraphics(managedVm.enable3DAcceleration ?? true)
            .withAccel(isNative && hvfConfigured ? QemuConstants.ACCEL_HVF : QemuConstants.ACCEL_TCG)
            .withSound(QemuConstants.SOUND_HDA)
            .withSound(QemuConstants.SOUND_HDA_DUPLEX)
            .withUsb(true)
            .withPortMappings(managedVm.portMappings)
            .withDevice(QemuConstants.USB_KEYBOARD)
            .withDevice(QemuConstants.USB_TABLET)
            .withDevice(QemuConstants.APPLE_SMC)
            .withNetwork(name: "network-0", device: networkDevice, macAddress: managedVm.macAddress)
    }

    fileprivate func createBuilderForARM() -> QemuCommandBuilder {
        if managedVm.os == QemuConstants.OS_IOS {
            return createBuilderForIOSGuests()
        }

        return QemuCommandBuilder(qemuPath: managedVm.qemuPath != nil ? managedVm.qemuPath! : qemuPath, architecture: managedVm.architecture)
            .withSerial(QemuConstants.SERIAL_STDIO)
            .withCpus(managedVm.cpus)
            .withBootArg(computeBootArg(managedVm))
            .withShowCursor(managedVm.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_VERSATILEPB, [])
            .withCpu(sanitizeCPUTypeForARM())
            .withMemory(managedVm.memory)
    }

    fileprivate func createBuilderForIOSGuests() -> QemuCommandBuilder {
        QemuCommandBuilder(qemuPath: managedVm.qemuPath != nil ? managedVm.qemuPath! : qemuPath, architecture: managedVm.architecture)
            .withSerial(QemuConstants.SERIAL_MON_STDIO)
            .withMachine(QemuConstants.MACHINE_TYPE_IPOD_TOUCH, ["bootrom=" + Utils.escape(managedVm.drives[1].path), "nand=" + Utils.escape(managedVm.drives[0].path), "nor=" + Utils.escape(managedVm.drives[2].path)])
            .withCpu(sanitizeCPUTypeForARM())
            .withMemory(managedVm.memory)
            .withRtcEnabled(false)
            .withLogging(QemuConstants.LOG_UNIMPLEMENTED)
    }

    fileprivate func createBuilderForARM64() -> QemuCommandBuilder {
        let isNative = Utils.hostArchitecture() == QemuConstants.HOST_ARM64 && !Utils.isRunningInEmulation()
        let hvfConfigured = managedVm.hvf != nil ? managedVm.hvf! : Utils.getAccelForSubType(managedVm.os, managedVm.subtype)
        let networkDevice = managedVm.networkDevice != nil ? managedVm.networkDevice! : Utils.getNetworkForSubType(managedVm.os, managedVm.subtype, managedVm.architecture)
        var videoDevice = managedVm.videoDevice != nil ? managedVm.videoDevice! : Utils.getVideoForSubType(managedVm.os, managedVm.subtype)
        if managedVm.enable3DAcceleration ?? false {
            videoDevice = Utils.convertDeviceToGLVariant(videoDevice)
        }

        return QemuCommandBuilder(qemuPath: managedVm.qemuPath != nil ? managedVm.qemuPath! : qemuPath, architecture: managedVm.architecture)
            .withCpus(managedVm.cpus)
            .withMachine(QemuConstants.MACHINE_TYPE_VIRT_HIGHMEM, [])
            .withCpu(sanitizeCPUTypeForARM64(isNative))
            .withMemory(managedVm.memory)
            .withAccel(isNative && hvfConfigured ? QemuConstants.ACCEL_HVF : nil)
            .withDisplay(managedVm.qemuDisplay)
            .withEnable3D(managedVm.enable3DAcceleration ?? false)
            .withShowCursor(managedVm.os == QemuConstants.OS_LINUX ? true : false)
            .withSound(QemuConstants.SOUND_HDA)
            .withSound(QemuConstants.SOUND_HDA_DUPLEX)
            .withDevice(QemuConstants.NEC_USB_XHCI)
            .withDevice(QemuConstants.USB_KEYBOARD)
            .withDevice(QemuConstants.USB_TABLET)
            .withVga(videoDevice)
            .withNic(QemuConstants.NIC_VIRTIO)
            .withNetwork(name: "network-0", device: networkDevice, macAddress: managedVm.macAddress)
            .withTpm(Utils.getTPMForSubType(managedVm.os, managedVm.subtype) ? managedVm.path : nil, QemuConstants.TPM_TIS_DEVICE)
    }

    fileprivate func createBuilderForM68k() -> QemuCommandBuilder {
        QemuCommandBuilder(qemuPath: managedVm.qemuPath != nil ? managedVm.qemuPath! : qemuPath, architecture: managedVm.architecture)
            .withCpus(managedVm.cpus)
            .withBootArg(computeBootArg(managedVm))
            .withShowCursor(managedVm.os == QemuConstants.OS_LINUX ? true : false)
            .withMachine(QemuConstants.MACHINE_TYPE_Q800, [])
            .withMemory(managedVm.memory)
    }

    fileprivate func computeBootArg(_ vm: VirtualMachine) -> String {
        for drive in vm.drives {
            if drive.isBootDrive {
                if drive.mediaType == QemuConstants.MEDIATYPE_DISK {
                    return QemuConstants.ARG_HD
                }
                if drive.mediaType == QemuConstants.MEDIATYPE_CDROM {
                    return QemuConstants.ARG_CD
                }
            }
        }

        return QemuConstants.ARG_NET
    }

    fileprivate func searchForDrive(_ vm: VirtualMachine, _ mediaType: String) -> Bool {
        for virtualDrive in vm.drives {
            if virtualDrive.mediaType == mediaType {
                return true
            }
        }
        return false
    }

    fileprivate func sanitizeMachineTypeForPPC() -> String {
        var machineType = Utils.getMachineTypeForSubType(managedVm.os, managedVm.subtype)
        if machineType != QemuConstants.MACHINE_TYPE_MAC99, machineType != QemuConstants.MACHINE_TYPE_MAC99_PMU {
            machineType = QemuConstants.MACHINE_TYPE_MAC99_PMU
        }
        return machineType
    }

    fileprivate func sanitizeCPUTypeForIntel(_ isNative: Bool) -> String {
        var cpuType = Utils.getCpuTypeForSubType(managedVm.os, managedVm.subtype, isNative)
        if cpuType != QemuConstants.CPU_HOST_PDPE_1GB,
           cpuType != QemuConstants.CPU_PENRYN,
           cpuType != QemuConstants.CPU_PENRYN_SSE,
           cpuType != QemuConstants.CPU_SANDY_BRIDGE,
           cpuType != QemuConstants.CPU_IVY_BRIDGE,
           cpuType != QemuConstants.CPU_SKYLAKE_CLIENT,
           cpuType != QemuConstants.CPU_ICELAKE_SERVER,
           cpuType != QemuConstants.CPU_QEMU64,
           cpuType != QemuConstants.CPU_MAX_PDPE_1GB
        {
            cpuType = QemuConstants.CPU_MAX_PDPE_1GB
        }
        return cpuType
    }

    fileprivate func sanitizeCPUTypeForARM() -> String {
        var cpuType = Utils.getCpuTypeForSubType(managedVm.os, managedVm.subtype, false)
        if cpuType != QemuConstants.CPU_ARM1176,
           cpuType != QemuConstants.CPU_MAX
        {
            cpuType = QemuConstants.CPU_ARM1176
        }
        return cpuType
    }

    fileprivate func sanitizeCPUTypeForARM64(_ isNative: Bool) -> String {
        var cpuType = Utils.getCpuTypeForSubType(managedVm.os, managedVm.subtype, isNative)
        if cpuType != QemuConstants.CPU_HOST,
           cpuType != QemuConstants.CPU_CORTEX_A72,
           cpuType != QemuConstants.CPU_MAX
        {
            cpuType = QemuConstants.CPU_MAX
        }
        return cpuType
    }

    fileprivate func extendPathForMacOSInstaller(_ path: String, _ subtype: String?) -> String {
        var installDMGFile = ""
        if subtype == QemuConstants.SUB_MAC_LION ||
            subtype == QemuConstants.SUB_MAC_MOUNTAIN_LION ||
            subtype == QemuConstants.SUB_MAC_MAVERICKS ||
            subtype == QemuConstants.SUB_MAC_YOSEMITE ||
            subtype == QemuConstants.SUB_MAC_EL_CAPITAN ||
            subtype == QemuConstants.SUB_MAC_SIERRA
        {
            installDMGFile = "/Contents/SharedSupport/InstallESD.dmg"
        } else if subtype == QemuConstants.SUB_MAC_HIGH_SIERRA ||
            subtype == QemuConstants.SUB_MAC_MOJAVE ||
            subtype == QemuConstants.SUB_MAC_CATALINA
        {
            installDMGFile = "/Contents/SharedSupport/BaseSystem.dmg"
        } else {
            installDMGFile = "/Contents/SharedSupport/SharedSupport.dmg"
        }
        return path + installDMGFile
    }

    func waitForCompletion() {
        shell.waitForCommand()
    }

    func isVMRunning() -> Bool {
        shell.isRunning()
    }

    func stopVM(guestStopped _: Bool, uponCompletion _: (((any Error)?) -> Void)?) {
        shell.kill()
    }

    func stopVMGracefully() {
        stopVM(guestStopped: false)
    }

    func pauseVM() {}

    func abort() {}

    func getStandardError() -> String {
        shell.readFromStandardError()
    }

    func getStandardOutput() -> String {
        shell.readFromStandardOutput()
    }

    func getConsoleOutput() -> String {
        shell.readFromConsole()
    }
}
