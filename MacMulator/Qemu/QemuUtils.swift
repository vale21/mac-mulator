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
        }
        
        return QemuConstants.HD;
    }
    
    static func createDiskImage(path: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32) -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();

        let command: String =
            QemuImgCommandBuilder(qemuPath:qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CREATE)
            .withFormat(virtualDrive.format)
            .withSize(virtualDrive.size)
            .withName(virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION)
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
            .withShortSize(virtualDrive.size)
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
    
    static func getQemuVersion(uponCompletion callback: @escaping (String?) -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
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
                        } else {
                            callback(nil);
                        }
                    }
            });
        }
    }
    
    static func isMacModern(_ subtype: String?) -> Bool {
        let ret =
        (subtype == QemuConstants.SUB_MAC_MONTEREY ||
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
