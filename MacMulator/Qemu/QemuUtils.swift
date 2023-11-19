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
            return "(Plain data)";
        } else if format == QemuConstants.FORMAT_QCOW2 {
            return "(Qemu Copy On Write format)";
        }
        
        return "";
    }
    
    static func getDriveTypeDescription(_ driveType: String) -> String {
        if driveType == QemuConstants.MEDIATYPE_CDROM {
            return QemuConstants.CD;
        } else if driveType == QemuConstants.MEDIATYPE_EFI {
            return QemuConstants.EFI;
        } else if driveType == QemuConstants.MEDIATYPE_USB {
            return QemuConstants.USB;
        } else if driveType == QemuConstants.MEDIATYPE_IPSW {
            return QemuConstants.IPSW;
        } else if driveType == QemuConstants.MEDIATYPE_NVRAM {
            return QemuConstants.NVRAM;
        } else if driveType == QemuConstants.MEDIATYPE_NVME {
            return QemuConstants.NVME;
        }
        
        return QemuConstants.HD;
    }
    
    static func createDiskImage(path: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32) -> Void) {
        createDiskImage(path: path, name: virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION, format: virtualDrive.format, size: String(virtualDrive.size) + "G", uponCompletion: callback)
    }
    
    static func createDiskImage(path: String, name: String, format: String, size: String, uponCompletion callback: @escaping (Int32) -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();

        let command: String =
            QemuImgCommandBuilder(qemuPath:qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CREATE)
            .withFormat(format)
            .withSize(size)
            .withName(name)
            .build();
        
        shell.runCommand(command, path, uponCompletion: callback);
    }
    
    static func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, uponCompletion callback: @escaping (Int32) -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_RESIZE)
            .withName(virtualDrive.path)
            .withShrinkArg(shrink)
            .withShortSize(String(virtualDrive.size) + "G")
            .build();
        
        shell.runCommand(command, path, uponCompletion: callback);
    }
    
    static func convertDiskImage(_ virtualDrive: VirtualDrive, _ path: String, oldFormat: String, uponCompletion callback: @escaping (Int32) -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CONVERT)
            .withFormat(oldFormat)
            .withTargetFormat(virtualDrive.format)
            .withName(virtualDrive.path)
            .withTargetName(virtualDrive.path)
            .build();
        
        shell.runCommand(command, path, uponCompletion: callback);
    }
    
    static func convertVHDXToDiskImage(vhdxPath: String, vmPath: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32, Int32) -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CONVERT)
            .withName(vhdxPath)
            .withTargetName(Utils.escape(virtualDrive.path))
            .build();
        
        shell.runCommand(command, vmPath, uponCompletion: {
            terminationCode in
            
            if terminationCode == 0 {
                QemuUtils.getDiskImageInfo(virtualDrive.path, vmPath, uponCompletion: {
                    infoCode, output in
                    if infoCode == 0 {
                        let driveSize = Utils.extractDriveSize(output)
                        if let driveSize = driveSize {
                            callback(infoCode, driveSize)
                        } else {
                            callback(infoCode, -1)
                        }
                    } else {
                        callback(infoCode, -1)
                    }
                })
            } else {
                callback(terminationCode, -1)
            }
            
        })
    }
    
    static func createAuxiliaryDriveFilesOnDisk(_ vm: VirtualMachine) {
        if vm.architecture == QemuConstants.ARCH_ARM64 || vm.architecture == QemuConstants.ARCH_X64 && vm.os == QemuConstants.OS_MAC {
            let virtualEfi = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_EFI + "-0." + MacMulatorConstants.EFI_EXTENSION,
                name: QemuConstants.MEDIATYPE_EFI + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_EFI,
                size: 0);
            vm.addVirtualDrive(virtualEfi)
        }
        
        if vm.architecture == QemuConstants.ARCH_ARM64 {
            let virtualNvram = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_NVRAM + "-0",
                name: QemuConstants.MEDIATYPE_NVRAM + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_NVRAM,
                size: 0);
            vm.addVirtualDrive(virtualNvram)
        }
        
        if vm.architecture == QemuConstants.ARCH_X64 && vm.os == QemuConstants.OS_MAC {
            let openCore = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_OPENCORE + "-0." + MacMulatorConstants.IMG_EXTENSION,
                name: QemuConstants.MEDIATYPE_OPENCORE + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_OPENCORE,
                size: 0);
            vm.addVirtualDrive(openCore);
        }
        
        if (vm.architecture == QemuConstants.ARCH_ARM64) {
            try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "ARM_QEMU_EFI.fd", ofType: nil)!, toPath: vm.path + "/efi-0.fd");
            let nvramDrive = Utils.findNvramDrive(vm.drives)
            if let nvramDrive = nvramDrive {
                QemuUtils.createDiskImage(path: vm.path, name: nvramDrive.name, format: nvramDrive.format, size: "67108864", uponCompletion: { result in })
            }
        }
        
        if (vm.architecture == QemuConstants.ARCH_X64 && vm.os == QemuConstants.OS_MAC) {
            var opencore: String = "";
            if QemuUtils.isMacModern(vm.subtype) {
                opencore = QemuConstants.OPENCORE_MODERN;
            } else if QemuUtils.isMacLegacy(vm.subtype) {
                opencore = QemuConstants.OPENCORE_LEGACY;
            }
            
            try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "MACOS_EFI.fd", ofType: nil)!, toPath: vm.path + "/efi-0.fd");
            let sourceURL = URL(fileURLWithPath: Bundle.main.path(forResource: opencore + ".zip", ofType: nil)!);
            let destinationURL = URL(fileURLWithPath: vm.path);
            try? FileManager.default.unzipItem(at: sourceURL, to: destinationURL, skipCRC32: true);
            
            // Rename unzipped image and clean up garbage empty folder
            try? FileManager.default.moveItem(atPath: vm.path + "/" + opencore + ".img", toPath: vm.path + "/opencore-0.img");
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: vm.path + "/__MACOSX"));
        }
    }
    
    static func deleteAuxiliaryDriveFilesOnDisk(_ vm: VirtualMachine) {
        if (vm.architecture == QemuConstants.ARCH_ARM64) {
            try? FileManager.default.removeItem(atPath: vm.path + "/efi-0.fd")
            let efiDrive = Utils.findEfiDrive(vm.drives)
            if let efiDrive = efiDrive {
                if let index = vm.drives.firstIndex(of: efiDrive) {
                    vm.drives.remove(at: index)
                }
            }
            
            try? FileManager.default.removeItem(atPath: vm.path + "/nvram-0")
            let nvramDrive = Utils.findNvramDrive(vm.drives)
            if let nvramDrive = nvramDrive {
                if let index = vm.drives.firstIndex(of: nvramDrive) {
                    vm.drives.remove(at: index)
                }
            }
        }
        if (vm.architecture == QemuConstants.ARCH_X64 && vm.os == QemuConstants.OS_MAC) {
            try? FileManager.default.removeItem(atPath: vm.path + "/efi-0.fd")
            try? FileManager.default.removeItem(atPath: vm.path + "/opencore-0")
        }
    }
    
    static func updateDiskImage(oldVirtualDrive: VirtualDrive, newVirtualDrive: VirtualDrive, path: String, uponCompletion callback: @escaping (Int32) -> Void) {
        if newVirtualDrive.size != oldVirtualDrive.size {
            resizeDiskImage(newVirtualDrive, path, shrink: (newVirtualDrive.size < oldVirtualDrive.size), uponCompletion: callback);
        }
        if newVirtualDrive.format != oldVirtualDrive.format {
            convertDiskImage(newVirtualDrive, path, oldFormat: oldVirtualDrive.format, uponCompletion: callback);
        }
    }
    
    static func getDiskImageInfo(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void) -> Void {
        getDiskImageInfo(virtualDrive.path, path, uponCompletion: callback);
    }
    
    static func getDiskImageInfo(_ drivePath: String, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void) -> Void {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_INFO)
            .withName(drivePath)
            .build();
        
        shell.runCommand(command, path, uponCompletion: { terminationCcode in
            callback(terminationCcode, shell.readFromStandardOutput());
        });
    }

    static func isBinaryAvailable(_ binary: String) -> Bool {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let fileManager = FileManager.default;
        
        return fileManager.fileExists(atPath: qemuPath + "/" + binary);
    }
    
    static func getQemuVersion(qemuPath: String, uponCompletion callback: @escaping (String?) -> Void) {
        if !isBinaryAvailable(QemuConstants.QEMU_IMG) {
            callback(nil);
        } else {
            let shell = Shell();
            let command = QemuImgCommandBuilder(qemuPath: qemuPath)
                .withCommand(QemuConstants.IMAGE_CMD_VERSION)
                .build();
            shell.runCommand(command, NSHomeDirectory(), uponCompletion: { terminationCode in
                if terminationCode == 0 {
                    let result = shell.readFromStandardOutput();
                    if result.count > 22 {
                        let version = result[result.index(result.startIndex, offsetBy: 17)..<result.index(result.startIndex, offsetBy: 22)];
                        callback(String(version));
                    }
                } else {
                    callback(nil);
                }
            });
        }
    }
    
    static func isMacModern(_ subtype: String?) -> Bool {
        let ret =
        (subtype == QemuConstants.SUB_MAC_VENTURA ||
        subtype == QemuConstants.SUB_MAC_MONTEREY ||
        subtype == QemuConstants.SUB_MAC_BIG_SUR ||
        subtype == QemuConstants.SUB_MAC_CATALINA);
        return ret;
    }
    
    static func isMacLegacy(_ subtype: String?) -> Bool {
        let ret =
        (subtype == QemuConstants.SUB_MAC_MOJAVE ||
        subtype == QemuConstants.SUB_MAC_HIGH_SIERRA ||
        subtype == QemuConstants.SUB_MAC_SIERRA ||
        subtype == QemuConstants.SUB_MAC_EL_CAPITAN ||
        subtype == QemuConstants.SUB_MAC_YOSEMITE ||
        subtype == QemuConstants.SUB_MAC_MAVERICKS ||
        subtype == QemuConstants.SUB_MAC_MOUNTAIN_LION ||
        subtype == QemuConstants.SUB_MAC_LION ||
        subtype == QemuConstants.SUB_MAC_SNOW_LEOPARD);
        return ret;
    }
    
    static func populateOpenCoreConfig(virtualMachine: VirtualMachine) {
        let shell = Shell();
        shell.runCommand("hdiutil attach -noverify " + Utils.escape(virtualMachine.path) + "/opencore-0.img", virtualMachine.path) { terminationCode in
            
            let shell2 = Shell();
            shell2.runCommand("system_profiler SPHardwareDataType -json", virtualMachine.path, uponCompletion: { terminationCode in
                let json = shell2.stdout;
                print(json)
                let jsonData = json.data(using: .utf8)!
                
                var systemProfilerData : SystemProfilerData? = nil;
                do {
                    systemProfilerData = try JSONDecoder().decode(SystemProfilerData.self, from: jsonData);
                } catch {
                    print("ERROR while reading System Profiler data: " + error.localizedDescription);
                }
                
                let machineDetails = systemProfilerData?.SPHardwareDataType[0];
                    
                let shell3 = Shell();
                shell3.runCommand("cp /Volumes/OPENCORE/EFI/OC/config.plist /Volumes/OPENCORE/EFI/OC/config.plist.template", virtualMachine.path, uponCompletion: { terminationCode in
                    do {
                        var plistContent = try String(contentsOfFile: "/Volumes/OPENCORE/EFI/OC/config.plist.template");
                            
                        plistContent = plistContent.replacingOccurrences(of: "{screenResolution}", with: Utils.getResolutionOnly(virtualMachine.displayResolution));
                        plistContent = plistContent.replacingOccurrences(of: "{macProductName}", with: machineDetails?.machine_model ?? "MacPro7,1")
                        plistContent = plistContent.replacingOccurrences(of: "{serialNumber}", with: machineDetails?.serial_number ?? "ABCDEFG");
                        plistContent = plistContent.replacingOccurrences(of: "{hardwareUUID}", with: machineDetails?.platform_UUID ?? "000-000");
                            
                        try plistContent.write(toFile: "/Volumes/OPENCORE/EFI/OC/config.plist", atomically: false, encoding: .utf8);
                            
                        let shell4 = Shell();
                        shell4.runCommand("hdiutil detach /Volumes/OPENCORE", virtualMachine.path, uponCompletion: { terminationCode in
                            print("Done");
                        });
                    } catch {
                        print("ERROR while reading/writing OpenCore config.plist: " + error.localizedDescription);
                    }
                });
            });
        }
    }
    
    static func restoreOpenCoreConfigTemplate(virtualMachine: VirtualMachine) {
        let shell = Shell();
        shell.runCommand("hdiutil attach -noverify " + Utils.escape(virtualMachine.path) + "/opencore-0.img", virtualMachine.path) { terminationCode in
            
            let shell2 = Shell();
            shell2.runCommand("mv /Volumes/OPENCORE/EFI/OC/config.plist.template /Volumes/OPENCORE/EFI/OC/config.plist", virtualMachine.path, uponCompletion: { terminationCode in
                let shell3 = Shell();
                shell3.runCommand("hdiutil detach -force /Volumes/OPENCORE", virtualMachine.path, uponCompletion: { terminationCode in
                    print("Done");
                });
            });
        }
    }
}
