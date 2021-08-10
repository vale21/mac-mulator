//
//  Utils.swift
//  MacMulator
//
//  Created by Vale on 03/02/21.
//

import Foundation
import Cocoa

class Utils {
    
    static let ALERT_RESP_OK = 1000;
    static let IMAGE_TYPES  = ["img", "iso", "cdr", "toast", "vhd", "vhdx", "qcow2", "qvd"];
    
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
        var ret = escape(string);
        if ret.hasSuffix("/") {
            ret = String(ret.dropLast());
        }
        return ret;
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
            if drive.mediaType == QemuConstants.MEDIATYPE_DISK {
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
    
    static func getIconForSubType(_ os: String, _ subtype: String) -> String {
        return getStringValueForSubType(os, subtype, 10, QemuConstants.OS_OTHER.lowercased());
    }
    
    static func getArchitectureForSubType(_ os: String, _ subtype: String) -> String {
        return getStringValueForSubType(os, subtype, 2, QemuConstants.ARCH_X64);
    }
    
    static func getCpusForSubType(_ os: String, _ subtype: String) -> Int {
        return getIntValueForSubType(os, subtype, 3, 1);
    }
    
    static func getMinMemoryForSubType(_ os: String, _ subtype: String) -> Int {
        return getIntValueForSubType(os, subtype, 4, 16);
    }
    
    static func getMaxMemoryForSubType(_ os: String, _ subtype: String) -> Int {
        return getIntValueForSubType(os, subtype, 5, 2048);
    }
    
    static func getDefaultMemoryForSubType(_ os: String, _ subtype: String) -> Int {
        return getIntValueForSubType(os, subtype, 6, 1024);
    }
    
    static func getMinDiskSizeForSubType(_ os: String, _ subtype: String) -> Int {
        return getIntValueForSubType(os, subtype, 7, 1);
    }
    
    static func getMaxDiskSizeForSubType(_ os: String, _ subtype: String) -> Int {
        return getIntValueForSubType(os, subtype, 8, 1024);
    }
    
    static func getDefaultDiskSizeForSubType(_ os: String, _ subtype: String) -> Int {
        return getIntValueForSubType(os, subtype, 9, 250);
    }
    
    static func computeDrivesTableIndex(_ virtualMachine: VirtualMachine?,  _ row: Int) -> Int {
        var counter = 0;
        var iterationIndex = 0;
        
        if let vm = virtualMachine {
            for drive in vm.drives {
                if iterationIndex > row {
                    // end loop and return
                    return row + counter;
                }
                if drive.mediaType == QemuConstants.MEDIATYPE_EFI {
                    counter += 1;
                }
                iterationIndex += 1
            }
        }
        return row + counter;
    }
    
    fileprivate static func getStringValueForSubType(_ os: String, _ subtype: String, _ index: Int, _ defaultValue: String) -> String {
        for vmDefault in QemuConstants.vmDefaults {
            if vmDefault[0] as? String == os && vmDefault[1] as? String == subtype {
                return vmDefault[index] as! String;
            }
        }
        return defaultValue;
    }
    
    fileprivate static func getIntValueForSubType(_ os: String, _ subtype: String, _ index: Int, _ defaultValue: Int) -> Int {
        for vmDefault in QemuConstants.vmDefaults {
            if vmDefault[0] as? String == os && vmDefault[1] as? String == subtype {
                return vmDefault[index] as! Int;
            }
        }
        return defaultValue;
    }
}
