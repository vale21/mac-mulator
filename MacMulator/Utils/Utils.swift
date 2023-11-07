//
//  Utils.swift
//  MacMulator
//
//  Created by Vale on 03/02/21.
//

import Foundation
import Cocoa

enum ValidationError: Error, CustomStringConvertible {
    case sudoNotAllowed
    case workingPathError(qemuPath: String, command: String)
    case executableError(allowed: String, command: String)
    case genericError
    
    var description: String {
        switch self {
        case .sudoNotAllowed:
            return "Incorrect Qemu command provided: The usage of sudo command is not allowed."
        case .workingPathError(let qemuPath, let command):
            return "Incorrect Qemu command provided: The provided executable does not run in the correct path. \n\nExpected path is: \"" + qemuPath + "\".\n\nProvided command was: " + Utils.truncateString(command, 25)
        case .executableError(let allowed, let command):
            return "Incorrect Qemu command provided: The provided executable Is not a Qemu Executable. \n\nAllowed executables are: " + allowed + ".\n\nProvided command was: " + Utils.truncateString(command, 50)
        case .genericError:
            return "The provided Qemu executable is broken or unsupported"
        }
    }
}

class Utils {
    
    static let ALERT_RESP_OK = 1000;
    static let IMAGE_TYPES  = ["img", "iso", "cdr", "toast", "vhd", "vhdx", "qcow2", "qvd", "dmg", "app", "ipsw"];
    
    static func createDocumentPackage(_ path: String) throws {
        let fileManager = FileManager.default;
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil);
    }
    
    static func removeDocumentPackage(_ path: String) throws {
        let fileManager = FileManager.default;
        try fileManager.removeItem(at: URL(fileURLWithPath: path));
    }
    
    static func showFileSelector(fileTypes: [String], uponSelection: (NSOpenPanel) -> Void ) -> Void {
        let panel = NSOpenPanel();
        panel.canChooseFiles = true;
        panel.canChooseDirectories = false;
        panel.allowsMultipleSelection = false;
        panel.allowedFileTypes = fileTypes;
        panel.allowsOtherFileTypes = false;
        
        let wasOk = panel.runModal();
        if wasOk == NSApplication.ModalResponse.OK {
            uponSelection(panel);
        }
    }
    
    static func showDirectorySelector(uponSelection: (NSOpenPanel) -> Void ) -> Void {
        let panel = NSOpenPanel();
        panel.canChooseFiles = false;
        panel.canChooseDirectories = true;
        panel.allowsMultipleSelection = false;
        
        let wasOk = panel.runModal();
        if wasOk == NSApplication.ModalResponse.OK {
            uponSelection(panel);
        }
    }
    
    static func showAlert(window: NSWindow, style: NSAlert.Style, message: String) {
        let alert: NSAlert = NSAlert();
        alert.alertStyle = style;
        alert.messageText = message;
        alert.addButton(withTitle: "OK");
        alert.beginSheetModal(for: window);
    }
    
    static func showAlert(window: NSWindow, style: NSAlert.Style, message: String, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        let alert: NSAlert = NSAlert();
        alert.alertStyle = style;
        alert.messageText = message;
        alert.addButton(withTitle: "OK");
        alert.beginSheetModal(for: window, completionHandler: handler);
    }
    
    static func showPrompt(window: NSWindow, style: NSAlert.Style, message: String, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        let alert: NSAlert = NSAlert();
        alert.alertStyle = style;
        alert.messageText = message;
        alert.addButton(withTitle: "OK");
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window, completionHandler: handler);
    }
    
    static func showPrompt(window: NSWindow, style: NSAlert.Style, message: String) -> NSApplication.ModalResponse {
        let alert: NSAlert = NSAlert();
        alert.alertStyle = style;
        alert.messageText = message;
        alert.addButton(withTitle: "OK");
        alert.addButton(withTitle: "Cancel");
        return alert.runModal();
    }
    
    
    static func escape(_ string: String) -> String {
        var replaced =  string.replacingOccurrences(of: " ", with: "\\ ");
        replaced =  replaced.replacingOccurrences(of: "(", with: "\\(");
        replaced =  replaced.replacingOccurrences(of: ")", with: "\\)");
        return replaced;
    }
    
    static func unescape(_ string: String) -> String {
        var replaced = string.replacingOccurrences(of: "\\ ", with: " ");
        replaced = replaced.replacingOccurrences(of: "\\(", with: "(");
        replaced = replaced.replacingOccurrences(of: "\\)", with: ")");
        return replaced;
    }
    
    static func cleanFolderPath(_ string: String) -> String {
        var ret = string
        if ret.hasSuffix("/") {
            ret = String(ret.dropLast())
        }
        return ret
    }
    
    static func extractVMRootPath(_ vm: VirtualMachine) -> String {
        return String(
            vm.path
                .replacingOccurrences(of: "." + MacMulatorConstants.VM_EXTENSION, with: "")
                .replacingOccurrences(of: vm.displayName, with: "")
                .dropLast());
    }
    
    static func computeSizeOfPhysicalDrive(_ path: String, uponCompletion callback: @escaping (Int32, Int32) -> Void) {
        QemuUtils.getDiskImageInfo(path, NSHomeDirectory(), uponCompletion: {
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
    }
    
    static func extractDriveSize(_ driveInfo: String) -> Int32? {
        if let range: Range<String.Index> = driveInfo.range(of: "virtual size: ")  {
            let index: Int = driveInfo.distance(from: driveInfo.startIndex, to: range.lowerBound) + "virtual size: ".count
            print("index: ", index)
            
            if let range: Range<String.Index> = driveInfo.range(of: " GiB") {
                let index2: Int = driveInfo.distance(from: driveInfo.startIndex, to: range.lowerBound)
                print("index2: ", index2)
                
                return Int32(driveInfo.substring(with: String.Index(encodedOffset: index)..<String.Index(encodedOffset: index2)))
            }
        }
        
        return nil
    }
    
    fileprivate static func toDecimalWithAutoLocale(_ string: String) -> Decimal? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current;
        
        if let number = formatter.number(from: string) {
            return number.decimalValue
        }
        
        return nil
    }
    
    static func toDoubleWithAutoLocale(_ string: String) -> Double? {
        guard let decimal = Utils.toDecimalWithAutoLocale(string) else {
            return nil
        }
        
        return NSDecimalNumber(decimal:decimal).doubleValue
    }
    
    static func toInt32WithAutoLocale(_ string: String) -> Int32? {
        guard let decimal = Utils.toDecimalWithAutoLocale(string) else {
            return nil
        }
        
        return NSDecimalNumber(decimal:decimal).int32Value
    }
    
    static func formatMemory(_ value: Int32) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        
        if value < 1024 {
            return String(value) + " MB";
        } else {
            let number: NSNumber = Double(value) / 1024.0 as NSNumber ;
            let formatted: String = formatter.string(from: number) ?? "n/a";
            return formatted + " GB";
        }
    }
    
    static func formatDisk(_ value: Int32) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        
        if value == 0 {
            return "N/A";
        }
        
        if value < 1024 {
            return String(value) + " GB";
        } else {
            let number: NSNumber = Double(value) / 1024.0 as NSNumber ;
            let formatted: String = formatter.string(from: number) ?? "n/a";
            return formatted + " TB";
        }
    }
    
    static func findMainDrive(_ drives: [VirtualDrive]) -> VirtualDrive? {
        // purge non HDD drives
        var hdds: [VirtualDrive] = [];
        for drive: VirtualDrive in drives {
            if drive.mediaType == QemuConstants.MEDIATYPE_DISK || drive.mediaType == QemuConstants.MEDIATYPE_NVME {
                hdds.append(drive);
            }
        }
        
        if hdds.count == 0 {
            return nil;
        }
        if hdds.count == 1 {
            return hdds[0];
        }
        for drive: VirtualDrive in hdds {
            if drive.isBootDrive {
                return drive;
            }
        }
        return hdds[0];
    }
    
    static func findIPSWInstallDrive(_ drives: [VirtualDrive]) -> VirtualDrive? {
        // purge non IPSW drives
        var ipsws: [VirtualDrive] = [];
        for drive: VirtualDrive in drives {
            if drive.mediaType == QemuConstants.MEDIATYPE_IPSW {
                ipsws.append(drive);
            }
        }
        
        if ipsws.count == 0 {
            return nil;
        }
        return ipsws[0];
    }
    
    static func findUSBInstallDrive(_ drives: [VirtualDrive]) -> VirtualDrive? {
        // purge non USB drives
        var installers: [VirtualDrive] = [];
        for drive: VirtualDrive in drives {
            if drive.mediaType == QemuConstants.MEDIATYPE_USB {
                installers.append(drive);
            }
        }
        
        if installers.count == 0 {
            return nil;
        }
        return installers[0];
    }
    
    static func findNvramDrive(_ drives: [VirtualDrive]) -> VirtualDrive? {
        // purge non NVRAM drives
        var nvrams: [VirtualDrive] = [];
        for drive: VirtualDrive in drives {
            if drive.mediaType == QemuConstants.MEDIATYPE_NVRAM {
                nvrams.append(drive);
            }
        }
        
        if nvrams.count == 0 {
            return nil;
        }
        return nvrams[0];
    }
    
    static func getParentDir(_ path: String) -> String {
        guard let lastSlash = path.lastIndex(where: { char in char == "/"}) else { return path };
        return path.substring(to: lastSlash);
    }
    
    static func getDefaultVmFolderPath() -> String {
        return NSHomeDirectory() + "/MacMulator";
    }
    
    static func getDefaultQemuFolderPath() -> String {
        var qemuPath = "/opt/local/bin";
        if (!FileManager.default.fileExists(atPath: qemuPath + "/qemu-img")) {
            qemuPath = "/usr/local/bin";
        }
        return qemuPath;
    }
    
    static func hostArchitecture() -> String? {
        /// Returns a `String` representing the machine hardware name or nil if there was an error invoking `uname(_:)` or decoding the response.
        /// Return value is the equivalent to running `$ uname -m` in shell.
        var machineHardwareName: String? {
            var sysinfo = utsname()
            let result = uname(&sysinfo)
            guard result == EXIT_SUCCESS else { return nil }
            let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
            guard let identifier = String(bytes: data, encoding: .ascii) else { return nil }
            return identifier.trimmingCharacters(in: .controlCharacters)
        }
        return machineHardwareName;
    }
    
    static func isRunningInEmulation() -> Bool {
        var ret = Int32(0)
        var size = ret.bitWidth;
        
        let result = sysctlbyname("sysctl.proc_translated", &ret, &size, nil, 0)
        if result == -1 {
            if (errno == ENOENT){
                return false;
            }
            return true;
        }
        return false;
    }
    
    static func getMachineArchitecture(_ qemuExecutable: String) -> String {
        switch qemuExecutable {
        case QemuConstants.ARCH_X86:
            return QemuConstants.HOST_I386;
        case QemuConstants.ARCH_X64:
            return QemuConstants.HOST_X86_64;
        case QemuConstants.ARCH_ARM:
            return QemuConstants.HOST_ARM;
        case QemuConstants.ARCH_ARM64:
            return QemuConstants.HOST_ARM64;
        case QemuConstants.ARCH_PPC:
            return QemuConstants.HOST_PPC;
        case QemuConstants.ARCH_PPC64:
            return QemuConstants.HOST_PPC64;
        case QemuConstants.ARCH_RISCV32:
            return QemuConstants.HOST_RISCV32;
        case QemuConstants.ARCH_RISCV64:
            return QemuConstants.HOST_RISCV64;
        case QemuConstants.ARCH_68K:
            return QemuConstants.HOST_68K;
        default:
            return qemuExecutable;
        }
    }
    
    static func describeArchitecture(_ architecture: String?) -> String {
        switch architecture {
        case QemuConstants.HOST_I386:
            return QemuConstants.HOST_DESC_I386
        case QemuConstants.HOST_X86_64:
            return QemuConstants.HOST_DESC_X86_64
        case QemuConstants.HOST_ARM:
            return QemuConstants.HOST_DESC_ARM
        case QemuConstants.HOST_ARM64:
            return QemuConstants.HOST_DESC_ARM64
        case QemuConstants.HOST_PPC:
            return QemuConstants.HOST_DESC_PPC
        case QemuConstants.HOST_PPC64:
            return QemuConstants.HOST_DESC_PPC64
        case QemuConstants.HOST_RISCV32:
            return QemuConstants.HOST_DESC_RISCV32
        case QemuConstants.HOST_RISCV64:
            return QemuConstants.HOST_DESC_RISCV64
        case QemuConstants.HOST_68K:
            return QemuConstants.HOST_DESC_68K
        default:
            return ""
        }
    }
    
    static func directoryExists(_ path: String) -> Bool {
        var isDir : ObjCBool = true
        return FileManager.default.fileExists(atPath: path, isDirectory:&isDir);
    }
    
    static func countSubTypes(_ os: String?) -> Int {
        if os == nil {
            return 1;
        }
        
        var count = 0;
        for vmDefault in QemuConstants.vmDefaults {
            if vmDefault[0] as? String == os {
                count += 1;
            }
        }
        return count;
    }
    
    static func getSubType(_ os: String?, _ index: Int?) -> String {
        if os == nil || index == nil {
            return QemuConstants.SUB_OTHER_GENERIC;
        }
        
        var count = -1;
        for vmDefault in QemuConstants.vmDefaults {
            if vmDefault[0] as? String == os {
                count += 1;
                if count == index {
                    return vmDefault[1] as! String;
                }
            }
        }
        return QemuConstants.SUB_OTHER_GENERIC;
    }
    
    static func getIndexOfSubType(_ os: String, _ subtype: String) -> Int {
        var count = -1;
        for vmDefault in QemuConstants.vmDefaults {
            if vmDefault[0] as? String == os {
                count += 1;
                if (vmDefault[1] as? String == subtype) {
                    return count;
                }
            }
        }
        return 0;
    }
    
    static func getIconForSubType(_ os: String, _ subtype: String?) -> String {
        return getStringValueForSubType(os, subtype, 10) ?? QemuConstants.OS_OTHER.lowercased();
    }
    
    static func getArchitectureForSubType(_ os: String, _ subtype: String?) -> String {
        return getStringValueForSubType(os, subtype, 2) ?? QemuConstants.ARCH_X64;
    }
    
    static func getCpusForSubType(_ os: String, _ subtype: String?) -> Int {
        return getIntValueForSubType(os, subtype, 3, 1);
    }
    
    static func getMinMemoryForSubType(_ os: String, _ subtype: String?) -> Int {
        return getIntValueForSubType(os, subtype, 4, 16);
    }
    
    static func getMaxMemoryForSubType(_ os: String, _ subtype: String?) -> Int {
        return getIntValueForSubType(os, subtype, 5, 2048);
    }
    
    static func getDefaultMemoryForSubType(_ os: String, _ subtype: String?) -> Int {
        return getIntValueForSubType(os, subtype, 6, 1024);
    }
    
    static func getMinDiskSizeForSubType(_ os: String, _ subtype: String?) -> Int {
        return getIntValueForSubType(os, subtype, 7, 1);
    }
    
    static func getMaxDiskSizeForSubType(_ os: String, _ subtype: String?) -> Int {
        return getIntValueForSubType(os, subtype, 8, 1024);
    }
    
    static func getDefaultDiskSizeForSubType(_ os: String, _ subtype: String?) -> Int {
        return getIntValueForSubType(os, subtype, 9, 250);
    }
    
    static func getMachineTypeForSubType(_ os: String, _ subtype: String?) -> String {
        return getStringValueForSubType(os, subtype, 11) ?? QemuConstants.MACHINE_TYPE_Q35;
    }
    
    static func getCpuTypeForSubType(_ os: String, _ subtype: String?, _ isNative: Bool) -> String {
        let definedCpu = getStringValueForSubType(os, subtype, 12);
        if let cpu = definedCpu {
            return cpu;
        } else {
            return isNative ? QemuConstants.CPU_HOST : QemuConstants.CPU_QEMU64
        }
    }
    
    static func getAccelForSubType(_ os: String, _ subtype: String?) -> Bool {
        return getBoolValueForSubType(os, subtype, 13, true);
    }
    
    static func getNetworkForSubType(_ os: String, _ subtype: String?) -> String {
        return getStringValueForSubType(os, subtype, 14) ?? QemuConstants.NETWORK_VIRTIO_NET_PCI
    }
    
    static func getIUrlForSubType(_ os: String, _ subtype: String?) -> String {
        return getStringValueForSubType(os, subtype, 16) ?? QemuConstants.URL_APPLE_COM
    }
    
    static func computeDrivesTableSize(_ virtualMachine: VirtualMachine?) -> Int {
        var size = 0;
        if let vm = virtualMachine {
            for drive in vm.drives {
                if drive.mediaType != QemuConstants.MEDIATYPE_EFI && drive.mediaType != QemuConstants.MEDIATYPE_OPENCORE && drive.mediaType != QemuConstants.MEDIATYPE_NVRAM {
                    size += 1;
                }
            }
        }
        return size;
    }
    
    static func computeDrivesTableIndex(_ virtualMachine: VirtualMachine?,  _ row: Int) -> Int {
        var counter = 0;
        var iterationIndex = 0;
        
        if let vm = virtualMachine {
            for drive in vm.drives {
                if iterationIndex > (row + counter) {
                    // end loop and return
                    return row + counter;
                }
                if drive.mediaType == QemuConstants.MEDIATYPE_EFI || drive.mediaType == QemuConstants.MEDIATYPE_OPENCORE || drive.mediaType == QemuConstants.MEDIATYPE_NVRAM {
                    counter += 1;
                }
                iterationIndex += 1
            }
        }
        return row + counter;
    }
    
    static func computeNextDriveIndex(_ virtualMachine: VirtualMachine?, _ mediaType: String) -> Int {
        var index = 0;
        if let vm = virtualMachine {
            for drive in vm.drives {
                if drive.mediaType == mediaType {
                    let driveIndex = Int(drive.name.split(separator: "-")[1])!; // split disk-x at the index of - and take the second part
                    if driveIndex >= index {
                        index = driveIndex + 1;
                    }
                }
            }
        }
        return index
    }
    
    static func getResolutionOnly(_ resolutionWithDepth: String) -> String {
        return resolutionWithDepth.replacingOccurrences(of: "x32", with: "");
    }
    
    static func getResolutionElements(_ resolutionWithDepth: String) -> [Int] {
        let stringElements:[Substring] = resolutionWithDepth.split(separator: "x");
        var ret: [Int] = [];
        ret.append(Int(stringElements[0])!);
        ret.append(Int(stringElements[1])!);
        
        return ret;
    }
    
    static func getOriginElements(_ origin: String) -> [String] {
        let stringElements:[Substring] = origin.split(separator: ";");
        var ret: [String] = [];
        ret.append(String(stringElements[0]))
        ret.append(String(stringElements[1]))
        
        return ret;
    }
    
    static func isIpswInstallMediaProvided(_ installMedia: String) -> Bool {
        return installMedia != "" && installMedia.hasSuffix(".ipsw");
    }
    
    static func isVirtualizationFrameworkPreferred(_ vm: VirtualMachine) -> Bool
    {
        return Utils.isVirtualizationFrameworkPreferred(os: vm.os, subtype: vm.subtype, architecture: vm.architecture)
    }
    
    static func isVirtualizationFrameworkPreferred(os: String, subtype: String, architecture: String) -> Bool
    {
        if #available(macOS 13.0, *) {
            return (os == QemuConstants.OS_LINUX && Utils.hostArchitecture() == Utils.getMachineArchitecture(architecture)) || isMacVMWithOSVirtualizationFramework(os: os, subtype: subtype)
        }
        if #available(macOS 12.0, *) {
            return isMacVMWithOSVirtualizationFramework(os: os, subtype: subtype)
        }
        return false
    }
    
    
    
    static func isMacVMWithOSVirtualizationFramework(os: String, subtype: String) -> Bool {
        if #available(macOS 12.0, *) {
            return Utils.hostArchitecture() == QemuConstants.HOST_ARM64 && Utils.isMacVersionWithVirtualizationFramework(os: os, subtype: subtype)
        }
        return false
    }
    
    static func isPauseSupported(_ vm: VirtualMachine) -> Bool {
        if #available(macOS 14.0, *) {
            return isVirtualizationFrameworkPreferred(vm) && vm.pauseSupported == true
        }
        return false
    }
    
    static func getUnavailabilityMessage(_ vm: VirtualMachine) -> String {
        if #available(macOS 13.0, *) {
            let hostArchitecture = Utils.hostArchitecture()
            let vmArchitecture = Utils.getMachineArchitecture(vm.architecture)
            if hostArchitecture != vmArchitecture {
                return "The VM cannot be started because it is an " + Utils.describeArchitecture(vmArchitecture) + " VM and cannot run on an " + Utils.describeArchitecture(hostArchitecture) + " Mac."
            } else if Utils.hostArchitecture() != QemuConstants.HOST_ARM64 && isMacVersionWithVirtualizationFramework(os: vm.os, subtype: vm.subtype) {
                return "The VM cannot be started because it can run only on Apple Silicon hardware."
            } else {
                return "The VM cannot be started because Apple Virtualization Framework is not supported with this VM."
            }
        } else if #available(macOS 12.0, *) {
            if vm.os == QemuConstants.OS_LINUX {
                return "The VM cannot be started because Apple Virtualization Framework is not supported with Linux VMs on macOS Monterey."
            } else if Utils.hostArchitecture() != QemuConstants.HOST_ARM64 && isMacVersionWithVirtualizationFramework(os: vm.os, subtype: vm.subtype) {
                return "The VM cannot be started because it can run only on Apple Silicon hardware."
            } else {
                return "The VM cannot be started because Apple Virtualization Framework is not supported with this VM."
            }
        } else if #available(macOS 11.0, *) {
            return "The VM cannot be started because Apple Virtualization Framework is not supported on macOS Big Sur."
        } else if #available(macOS 10.15, *) {
            return "The VM cannot be started because Apple Virtualization Framework is not supported on macOS Catalina."
        } else if #available(macOS 10.14, *) {
            return "The VM cannot be started because Apple Virtualization Framework is not supported on macOS Mojave."
        } else if #available(macOS 10.13, *) {
            return "The VM cannot be started because Apple Virtualization Framework is not supported on macOS High Sierra."
        } else {
            return "The VM cannot be started because Apple Virtualization Framework is not supported on this Mac."
        }
    }
    
    static func getPreferredArchitecture() -> String {
#if arch(arm64)
        return QemuConstants.ARCH_ARM64
#else
        return QemuConstants.ARCH_X64
#endif
    }
    
    static func getPreferredMachineType() -> String {
#if arch(arm64)
        return QemuConstants.MACHINE_TYPE_VIRT_HIGHMEM
#else
        return QemuConstants.MACHINE_TYPE_Q35
#endif
    }
    
    static func getPreferredCPU() -> String {
#if arch(arm64)
        return QemuConstants.CPU_IVY_BRIDGE
#else
        return QemuConstants.CPU_MAX
#endif
    }
    
    static func random(digits:Int32) -> Int32 {
        var number = String()
        for _ in 1...digits {
            number += "\(Int.random(in: 1...9))"
        }
        return Int32(number) ?? 0
    }
    
    static func random(digits:Int, suffix:Int32) -> Int32 {
        var number = String()
        for _ in 1...digits {
            number += "\(Int.random(in: 1...9))"
        }
        number += String(suffix)
        return Int32(number) ?? 0
    }
    
    static func computeTimeRemaining(startTime: Int64, progress: Double) -> String {
        let currentTime = Int64(Date().timeIntervalSince1970)
 
        let timeDelta = Double(currentTime - startTime)
        let factor = timeDelta / progress
        let totalTime = 100.0 * factor
        let remainingTime = totalTime - timeDelta
        
        return formatTime(remainingTime)
    }
    
    static func formatTime(_ secs: Double) -> String {
        if secs < 30 {
            return String(Int(secs)) + " seconds"
        } else if secs > 30 && secs < 60 {
            return "less than a minute"
        } else if secs < (60 * 3) {
            let minutes = Int(secs / 60)
            let seconds = Int(secs.truncatingRemainder(dividingBy: 60) / 10) * 10
            if seconds > 0 {
                return String(minutes) + " minutes, " + String(seconds) + " seconds"
            } else {
                return String(minutes) + " minutes"
            }
        } else if secs < (3600) {
            let minutes = Int(secs / 60)
            return String(minutes) + " minutes"
        } else {
            let hours = Int(secs / 3600)
            let minutes = Int(secs.truncatingRemainder(dividingBy: 3600))
            return String(hours) + " hours, " + String(minutes) + " minutes"
        }
    }
    
    static func isVMAvailable(_ vm: VirtualMachine) -> Bool {
        if vm.type == nil || vm.type == MacMulatorConstants.QEMU_VM {
            return QemuUtils.isBinaryAvailable(vm.architecture)
        } else {
            return isVirtualizationFrameworkPreferred(vm)
        }
    }
    
    static func computeVMPath(vmName: String) -> String {
        let userDefaults = UserDefaults.standard;
        let path = userDefaults.string(forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH)!;
        return Utils.unescape(path) + "/" + vmName + "." + MacMulatorConstants.VM_EXTENSION;
    }
    
    static func truncateString(_ string: String, _ length: Int) -> String {
        if string.count <= length {
            return string
        } else {
            return string.prefix(length) + "..."
        }
    }
    
    static func isVHDXImage(_ path: String) -> Bool {
        // Case insensitive check for vhdx extension
        return path.uppercased().hasSuffix("." + QemuConstants.FORMAT_VHDX.uppercased())
    }
    
    static func isFullFeaturedMacOSVM(_ vm: VirtualMachine) -> Bool {
        if #available(macOS 13.0, *) {
            return Utils.isVMAvailable(vm) && Utils.isMacVMWithOSVirtualizationFramework(os: vm.os, subtype: vm.subtype)
        } else {
            return false
        }
    }
    
    static func removeUnexistingDrives(_ virtualMachine: VirtualMachine) {
        if let window = NSApp.mainWindow {
            for drive in virtualMachine.drives {
                if !Utils.driveExists(drive) {
                    Utils.showPrompt(window: window, style: NSAlert.Style.warning, message: "Drive " + drive.path + " was not found. Do you want to remove it?", completionHandler: {
                        response in if response.rawValue == Utils.ALERT_RESP_OK {
                            virtualMachine.drives.remove(at: virtualMachine.drives.firstIndex(where: { vd in return vd.name == drive.name })!);
                            virtualMachine.writeToPlist();
                        }});
                }
            }
        }
    }
    
    static func getMainScreenSize() -> String {
        if #available(macOS 12, *) {
            let topInset = NSScreen.main!.safeAreaInsets.top > 0 ? NSApplication.shared.mainMenu!.menuBarHeight : 0
            return String(format: "%dx%d", Int32(NSScreen.main!.frame.size.width), Int32(NSScreen.main!.frame.size.height - topInset))
        } else {
            return String(format: "%dx%d", Int32(NSScreen.main!.frame.size.width), Int32(NSScreen.main!.frame.size.height))
        }
    }
    
    static func getMainScreenSizeDesc() -> String {
        if #available(macOS 12, *) {
            let topInset = NSScreen.main!.safeAreaInsets.top > 0 ? NSApplication.shared.mainMenu!.menuBarHeight : 0
            return String(format: "%d x %d (Mac Main Screen)", Int32(NSScreen.main!.frame.size.width), Int32(NSScreen.main!.frame.size.height - topInset))
        } else {
            return String(format: "%d x %d (Mac Main Screen)", Int32(NSScreen.main!.frame.size.width), Int32(NSScreen.main!.frame.size.height))
        }
    }
    
    static func getCustomScreenSizeDesc(width: Int, heigh: Int) -> String {
            return String(format: "%d x %d (Last Used)", width, heigh)
    }
    
    fileprivate static func driveExists(_ drive: VirtualDrive) -> Bool {
        if (drive.mediaType == QemuConstants.MEDIATYPE_CDROM || drive.mediaType == QemuConstants.MEDIATYPE_USB || drive.mediaType == QemuConstants.MEDIATYPE_IPSW) {
            let filemanager = FileManager.default;
            return filemanager.fileExists(atPath: drive.path);
        }
        return true;
    }
    
    fileprivate static func getStringValueForSubType(_ os: String, _ subtype: String?, _ index: Int) -> String? {
        for vmDefault in QemuConstants.vmDefaults {
            if vmDefault[0] as? String == os && vmDefault[1] as? String == subtype {
                return vmDefault[index] as? String;
            }
        }
        return nil;
    }
    
    fileprivate static func getIntValueForSubType(_ os: String, _ subtype: String?, _ index: Int, _ defaultValue: Int) -> Int {
        for vmDefault in QemuConstants.vmDefaults {
            if vmDefault[0] as? String == os && vmDefault[1] as? String == subtype {
                return vmDefault[index] as! Int;
            }
        }
        return defaultValue;
    }
    
    fileprivate static func getBoolValueForSubType(_ os: String, _ subtype: String?, _ index: Int, _ defaultValue: Bool) -> Bool {
        for vmDefault in QemuConstants.vmDefaults {
            if vmDefault[0] as? String == os && vmDefault[1] as? String == subtype {
                return vmDefault[index] as! Bool;
            }
        }
        return defaultValue;
    }
    
    fileprivate static func isMacVersionWithVirtualizationFramework(os: String, subtype: String) -> Bool {
        return os == QemuConstants.OS_MAC &&
        (subtype == QemuConstants.SUB_MAC_MONTEREY || subtype == QemuConstants.SUB_MAC_VENTURA || subtype == QemuConstants.SUB_MAC_SONOMA)
    }
}
