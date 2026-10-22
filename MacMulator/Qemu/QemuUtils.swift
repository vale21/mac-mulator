//
//  QemuUtils.swift
//  MacMulator
//
//  Created by Vale on 18/02/21.
//

import Cocoa

class QemuUtils {
    static func getDriveFormatDescription(_ format: String) -> String {
        if format == QemuConstants.FORMAT_RAW {
            return "(Plain data)"
        } else if format == QemuConstants.FORMAT_QCOW2 {
            return "(Qemu Copy On Write format)"
        }

        return ""
    }

    static func getDriveTypeDescription(_ driveType: String) -> String {
        if driveType == QemuConstants.MEDIATYPE_CDROM {
            return QemuConstants.CD
        } else if driveType == QemuConstants.MEDIATYPE_EFI {
            return QemuConstants.EFI
        } else if driveType == QemuConstants.MEDIATYPE_USB {
            return QemuConstants.USB
        } else if driveType == QemuConstants.MEDIATYPE_USB_CDROM {
            return QemuConstants.USB_CDROM
        } else if driveType == QemuConstants.MEDIATYPE_IPSW {
            return QemuConstants.IPSW
        } else if driveType == QemuConstants.MEDIATYPE_NVRAM {
            return QemuConstants.NVRAM
        } else if driveType == QemuConstants.MEDIATYPE_NVME {
            return QemuConstants.NVME
        } else if driveType == QemuConstants.MEDIATYPE_NAND {
            return QemuConstants.NAND
        }

        return QemuConstants.HD
    }

    static func createAuxiliaryDriveFilesOnDisk(_ vm: VirtualMachine) {
        if Utils.getTPMForSubType(vm.os, vm.subtype) {
            try? FileManager.default.createDirectory(at: URL(fileURLWithPath: vm.path + "/tpm"), withIntermediateDirectories: false)
        }

        if vm.subtype == QemuConstants.SUB_WINDOWS_11 {
            let driversCdRom = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_USB_CDROM + "-windows-drivers-0." + MacMulatorConstants.ISO_EXTENSION,
                name: QemuConstants.MEDIATYPE_USB_CDROM + "-windows-drivers-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_USB_CDROM,
                size: 0
            )
            vm.addVirtualDrive(driversCdRom)

            let sourceURL = URL(fileURLWithPath: Bundle.main.path(forResource: "windows-11-drivers.iso.zip", ofType: nil)!)
            let destinationURL = URL(fileURLWithPath: vm.path)
            try? FileManager.default.unzipItem(at: sourceURL, to: destinationURL, skipCRC32: true)

            // Rename unzipped image and clean up garbage empty folder
            try? FileManager.default.moveItem(atPath: vm.path + "/windows-11-drivers.iso", toPath: vm.path + "/usb-cdrom-windows-drivers-0.iso")
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: vm.path + "/__MACOSX"))
        }

        if QemuUtils.requiresOpenCore(vm) {
            let openCore = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_OPENCORE + "-0." + MacMulatorConstants.IMG_EXTENSION,
                name: QemuConstants.MEDIATYPE_OPENCORE + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_OPENCORE,
                size: 0
            )
            vm.addVirtualDrive(openCore)
        }

        #if !APPSTORE
            // iPod touch guests need Apple's boot ROM and NOR images, which the App Store flavor does not ship.
            if vm.os == QemuConstants.OS_IOS {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "bootrom_240_4", ofType: nil)!, toPath: vm.path + "/bootrom-0")
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "nor_n72ap.bin", ofType: nil)!, toPath: vm.path + "/nor-0.bin")

                let virtualBootRom = VirtualDrive(
                    path: vm.path + "/" + QemuConstants.MEDIATYPE_BOOTROM + "-0",
                    name: QemuConstants.MEDIATYPE_BOOTROM + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_BOOTROM,
                    size: 0
                )
                vm.addVirtualDrive(virtualBootRom)

                let virtualNor = VirtualDrive(
                    path: vm.path + "/" + QemuConstants.MEDIATYPE_NOR + "-0." + MacMulatorConstants.BIN_EXTENSION,
                    name: QemuConstants.MEDIATYPE_NOR + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_NOR,
                    size: 0
                )
                vm.addVirtualDrive(virtualNor)
            }
        #endif
    }

    static func deleteAuxiliaryDriveFilesOnDisk(_ vm: VirtualMachine) {
        if vm.architecture == QemuConstants.ARCH_ARM64 {
            try? FileManager.default.removeItem(atPath: vm.path + "/efi-0.fd")
            let efiDrive = Utils.findEfiDrive(vm.drives)
            if let efiDrive {
                if let index = vm.drives.firstIndex(of: efiDrive) {
                    vm.drives.remove(at: index)
                }
            }

            try? FileManager.default.removeItem(atPath: vm.path + "/nvram-0")
            let nvramDrive = Utils.findNvramDrive(vm.drives)
            if let nvramDrive {
                if let index = vm.drives.firstIndex(of: nvramDrive) {
                    vm.drives.remove(at: index)
                }
            }
        }

        if vm.architecture == QemuConstants.ARCH_X64, vm.os == QemuConstants.OS_MAC {
            try? FileManager.default.removeItem(atPath: vm.path + "/efi-0.fd")
            try? FileManager.default.removeItem(atPath: vm.path + "/opencore-0")
        }

        if vm.subtype == QemuConstants.SUB_WINDOWS_11 {
            try? FileManager.default.removeItem(atPath: vm.path + "/efi-secure-0.fd")
            try? FileManager.default.removeItem(atPath: vm.path + "/opencore-0")
        }

        if vm.os == QemuConstants.OS_IOS {
            try? FileManager.default.removeItem(atPath: vm.path + "/bootrom-0")
            try? FileManager.default.removeItem(atPath: vm.path + "/nor-0.bin")
        }
    }

    static func isBinaryAvailable(_ binary: String, _ qemuPath: String?) -> Bool {
        guard let path = qemuPath == nil ? QemuUtils.getQemuPath() : qemuPath else { return false }

        switch binary {
        case QemuConstants.ARCH_X64:
            return QemuCapabilitiesReporter.getInstance(forQemuPath: path)?.hasx86_64Binary ?? false
        case QemuConstants.ARCH_X86:
            return QemuCapabilitiesReporter.getInstance(forQemuPath: path)?.hasX86Binary ?? false
        case QemuConstants.ARCH_ARM64:
            return QemuCapabilitiesReporter.getInstance(forQemuPath: path)?.hasAarch64Binary ?? false
        case QemuConstants.ARCH_ARM:
            return QemuCapabilitiesReporter.getInstance(forQemuPath: path)?.hasArmBinary ?? false
        case QemuConstants.ARCH_PPC64:
            return QemuCapabilitiesReporter.getInstance(forQemuPath: path)?.hasPowerPC64Binary ?? false
        case QemuConstants.ARCH_PPC:
            return QemuCapabilitiesReporter.getInstance(forQemuPath: path)?.hasPowerPCBinary ?? false
        case QemuConstants.ARCH_RISCV64:
            return QemuCapabilitiesReporter.getInstance(forQemuPath: path)?.hasRiscv64Binary ?? false
        case QemuConstants.ARCH_RISCV32:
            return QemuCapabilitiesReporter.getInstance(forQemuPath: path)?.hasRiscvBinary ?? false
        case QemuConstants.ARCH_68K:
            return QemuCapabilitiesReporter.getInstance(forQemuPath: path)?.hasM68kBinary ?? false
        case QemuConstants.QEMU_IMG:
            return QemuCapabilitiesReporter.getInstance(forQemuPath: path)?.hasQemuImgBinary ?? false
        case QemuConstants.SWTPM:
            return QemuCapabilitiesReporter.getInstance(forQemuPath: path)?.hasSwtpmBinary ?? false
        default:
            return false
        }
    }

    #if APPSTORE
        static let bundledQemuPath = Bundle.main.executableURL!.deletingLastPathComponent().path
        static let bundledQemuDataPath = Bundle.main.resourcePath! + "/qemu"
    #endif

    static func getQemuPath() -> String {
        #if APPSTORE
            return bundledQemuPath
        #else
            return UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!
        #endif
    }

    static func getQemuPath(for vm: VirtualMachine) -> String {
        #if APPSTORE
            return bundledQemuPath
        #else
            return vm.qemuPath ?? getQemuPath()
        #endif
    }

    static func isSpiceDisplayEnabled(_ vm: VirtualMachine) -> Bool {
        #if APPSTORE
            return true
        #else
            let capabilities = QemuCapabilitiesReporter.getInstance(forQemuPath: QemuUtils.getQemuPath(for: vm))
            if capabilities?.spiceSupported == true {
                return vm.enableSpiceDisplay == true
            } else {
                vm.enableSpiceDisplay = false
                return false
            }
        #endif
    }

    static func spiceSocketPath(forVMAt vmPath: String) -> String {
        #if APPSTORE
            return containerSocketPath("spice", vmPath)
        #else
            return vmPath + "/socket.spice"
        #endif
    }

    static func tpmSocketPath(forVMAt vmPath: String) -> String {
        #if APPSTORE
            return containerSocketPath("tpm", vmPath)
        #else
            return vmPath + "/tpm/socket"
        #endif
    }

    #if APPSTORE
        /// A unix socket path inside the sandbox container, unique per VM and short enough for sun_path.
        private static func containerSocketPath(_ prefix: String, _ vmPath: String) -> String {
            // FNV-1a hash of the path: stable across launches (unlike Hasher) and short.
            var hash: UInt64 = 0xCBF2_9CE4_8422_2325
            for byte in vmPath.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01B3
            }
            return NSTemporaryDirectory() + prefix + "-" + String(hash, radix: 16) + ".sock"
        }
    #endif

    static func removeDuplicateVideoAdapters(_ adapters: [String]) -> [String] {
        let aliases = [
            QemuConstants.VGA_VIRTIO_GPU_PCI: QemuConstants.VGA_VIRTIO_GPU,
            QemuConstants.VGA_VIRTIO_GPU_GL_PCI: QemuConstants.VGA_VIRTIO_GPU_GL,
            QemuConstants.VGA_QXL: QemuConstants.VGA_QXL_VGA,
        ]
        let normalized = adapters.map { aliases[$0] ?? $0 }
        let available = Set(normalized)

        var seen = Set<String>()
        return normalized.filter { adapter in
            if adapter.hasSuffix("-gl") || adapter.contains("-gl-") {
                let base = adapter.replacingOccurrences(of: "-gl", with: "")
                if available.contains(base) {
                    return false
                }
            }
            if adapter == QemuConstants.VGA_APPLE_GFX_PCI || adapter == QemuConstants.VGA_APPLE_GFX_MMIO {
                return false
            }
            return seen.insert(adapter).inserted
        }
    }

    static func getQemuVersion(qemuPath: String, uponCompletion callback: @escaping (String?) -> Void) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: qemuPath + "/" + QemuConstants.QEMU_IMG) {
            callback(nil)
            return
        }

        let shell = Shell()
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_VERSION)
            .build()

        shell.runCommand(command, NSHomeDirectory(), uponCompletion: { terminationCode in
            guard terminationCode == 0 else {
                callback(nil)
                return
            }

            let output = shell.readFromStandardOutput()

            let pattern = #"qemu-img version (\d+\.\d+(\.\d+)?)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(output.startIndex ..< output.endIndex, in: output)
                if let match = regex.firstMatch(in: output, options: [], range: range),
                   let versionRange = Range(match.range(at: 1), in: output)
                {
                    let version = String(output[versionRange])
                    callback(version)
                    return
                }
            }

            callback(nil)
        })
    }

    static func populateOpenCoreConfig(virtualMachine: VirtualMachine, uponCompletion callback: @escaping (Int32) -> Void) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: virtualMachine.path + "/opencore-0.img") {
            try? fileManager.removeItem(atPath: virtualMachine.path + "/opencore-0.img")
        }
        let sourceURL = URL(fileURLWithPath: Bundle.main.path(forResource: QemuConstants.OPENCORE + ".zip", ofType: nil)!)
        let destinationURL = URL(fileURLWithPath: virtualMachine.path)
        try? fileManager.unzipItem(at: sourceURL, to: destinationURL, skipCRC32: true)

        // Rename unzipped image and clean up garbage empty folder
        try? fileManager.moveItem(atPath: virtualMachine.path + "/" + QemuConstants.OPENCORE + ".img", toPath: virtualMachine.path + "/opencore-0.img")
        try? fileManager.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/__MACOSX"))
        let shell = Shell()
        shell.runCommand("hdiutil attach -noverify " + Utils.escape(virtualMachine.path) + "/opencore-0.img", virtualMachine.path) { terminationCode in

            let shell2 = Shell()
            shell2.runCommand("system_profiler SPHardwareDataType -json", virtualMachine.path, uponCompletion: { terminationCode in
                let json = shell2.stdout
                print(json)
                let jsonData = json.data(using: .utf8)!

                var systemProfilerData: SystemProfilerData?
                do {
                    systemProfilerData = try JSONDecoder().decode(SystemProfilerData.self, from: jsonData)
                } catch {
                    print("ERROR while reading System Profiler data: " + error.localizedDescription)
                }

                let machineDetails = systemProfilerData?.SPHardwareDataType[0]

                let shell3 = Shell()
                shell3.runCommand("cp /Volumes/OPENCORE/EFI/OC/config.plist /Volumes/OPENCORE/EFI/OC/config.plist.template", virtualMachine.path, uponCompletion: { terminationCode in
                    do {
                        var plistContent = try String(contentsOfFile: "/Volumes/OPENCORE/EFI/OC/config.plist.template")

                        print("Replacing screen resolution in OpenCore config...")
                        plistContent = plistContent.replacingOccurrences(of: "{screenResolution}", with: Utils.getResolutionOnly(virtualMachine.displayResolution))

                        print("Replacing product name in OpenCore config...")
                        plistContent = plistContent.replacingOccurrences(of: "{macProductName}", with: machineDetails?.machine_model ?? "MacPro7,1")

                        print("Replacing serial number in OpenCore config...")
                        plistContent = plistContent.replacingOccurrences(of: "{serialNumber}", with: machineDetails?.serial_number ?? "ABCDEFG")

                        print("Replacing hardware UUID in OpenCore config...")
                        plistContent = plistContent.replacingOccurrences(of: "{hardwareUUID}", with: machineDetails?.platform_UUID ?? "000-000")

                        print("Writing to plist...")
                        try plistContent.write(toFile: "/Volumes/OPENCORE/EFI/OC/config.plist", atomically: false, encoding: .utf8)

                        let shell4 = Shell()
                        shell4.runCommand("hdiutil detach /Volumes/OPENCORE -force", virtualMachine.path, uponCompletion: { terminationCode in
                            callback(terminationCode)
                        })
                    } catch {
                        print("ERROR while reading/writing OpenCore config.plist: " + error.localizedDescription)
                    }
                })
            })
        }
    }

    static func removeOpenCoreConfig(virtualMachine: VirtualMachine, uponCompletion _: @escaping (Int32) -> Void) {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/opencore-0.img"))
    }

    static func populateUEFIConfig(virtualMachine: VirtualMachine) {
        if !virtualMachine.containsVirtualDrive(virtualMachine.path + "/efi-0.fd") {
            let virtualEfi = VirtualDrive(
                path: virtualMachine.path + "/" + QemuConstants.MEDIATYPE_EFI + "-0." + MacMulatorConstants.EFI_EXTENSION,
                name: QemuConstants.MEDIATYPE_EFI + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_EFI,
                size: 0
            )
            virtualMachine.addVirtualDrive(virtualEfi)
            virtualMachine.writeToPlist()
        }
        if !FileManager.default.fileExists(atPath: virtualMachine.path + "/efi-0.fd") {
            if virtualMachine.architecture == QemuConstants.ARCH_X64 {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "EFI_x64.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-0.fd")
            } else if virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "EFI_ARM.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-0.fd")
            }
        }
        if virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
            if !virtualMachine.containsVirtualDrive(virtualMachine.path + "/efi-vars-0.fd") {
                let virtualEfi = VirtualDrive(
                    path: virtualMachine.path + "/" + QemuConstants.MEDIATYPE_EFI_VARS + "-0." + MacMulatorConstants.EFI_EXTENSION,
                    name: QemuConstants.MEDIATYPE_EFI_VARS + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_EFI_VARS,
                    size: 0
                )
                virtualMachine.addVirtualDrive(virtualEfi)
                virtualMachine.writeToPlist()
            }
            if !FileManager.default.fileExists(atPath: virtualMachine.path + "/efi-vars-0.fd") {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "EFI_VARS_ARM.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-vars-0.fd")
            }
        }
    }

    static func removeUEFIConfig(virtualMachine: VirtualMachine) {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/efi-0.fd"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/efi-vars-0.fd"))
        virtualMachine.removeVirtualDrive(virtualMachine.path + "/efi-0.fd")
        virtualMachine.removeVirtualDrive(virtualMachine.path + "/efi-vars-0.fd")
        virtualMachine.writeToPlist()
    }

    static func populateUEFISecureConfig(virtualMachine: VirtualMachine) {
        if !virtualMachine.containsVirtualDrive(virtualMachine.path + "/efi-secure-0.fd") {
            let virtualEfi = VirtualDrive(
                path: virtualMachine.path + "/" + QemuConstants.MEDIATYPE_EFI_SECURE + "-0." + MacMulatorConstants.EFI_EXTENSION,
                name: QemuConstants.MEDIATYPE_EFI_SECURE + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_EFI_SECURE,
                size: 0
            )
            virtualMachine.addVirtualDrive(virtualEfi)
            virtualMachine.writeToPlist()
        }
        if !FileManager.default.fileExists(atPath: virtualMachine.path + "/efi-secure-0.fd") {
            if virtualMachine.architecture == QemuConstants.ARCH_X64 {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "SECURE_EFI_x64.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-secure-0.fd")
            } else if virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "SECURE_EFI_ARM.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-secure-0.fd")
            }
        }
        if virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
            if !virtualMachine.containsVirtualDrive(virtualMachine.path + "/efi-secure-vars-0.fd") {
                let virtualEfi = VirtualDrive(
                    path: virtualMachine.path + "/" + QemuConstants.MEDIATYPE_EFI_SECURE_VARS + "-0." + MacMulatorConstants.EFI_EXTENSION,
                    name: QemuConstants.MEDIATYPE_EFI_SECURE_VARS + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_EFI_SECURE_VARS,
                    size: 0
                )
                virtualMachine.addVirtualDrive(virtualEfi)
                virtualMachine.writeToPlist()
            }
            if !FileManager.default.fileExists(atPath: virtualMachine.path + "/efi-secure-vars-0.fd") {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "SECURE_EFI_VARS_ARM.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-secure-vars-0.fd")
            }
        }
    }

    static func removeUEFISecureConfig(virtualMachine: VirtualMachine) {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/efi-secure-0.fd"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/efi-secure-vars-0.fd"))
        virtualMachine.removeVirtualDrive(virtualMachine.path + "/efi-secure-0.fd")
        virtualMachine.removeVirtualDrive(virtualMachine.path + "/efi-secure-vars-0.fd")
        virtualMachine.writeToPlist()
    }

    static func requiresOpenCore(_ vm: VirtualMachine) -> Bool {
        vm.os == QemuConstants.OS_MAC && vm.architecture == QemuConstants.ARCH_X64 // || (vm.subtype == QemuConstants.SUB_WINDOWS_11 && vm.architecture == QemuConstants.ARCH_X64)
    }
}
