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
    static let IMAGE_TYPES  = ["img", "iso", "cdr"];
    
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
    
    static func showPrompt(window: NSWindow, style: NSAlert.Style, message: String, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        let alert: NSAlert = NSAlert();
        alert.alertStyle = style;
        alert.messageText = message;
        alert.addButton(withTitle: "OK");
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window, completionHandler: handler);
    }
    
    static func escape(_ string: String) -> String {
        return string.replacingOccurrences(of: " ", with: "\\ ");
    }
    
    static func unescape(_ string: String) -> String {
        return string.replacingOccurrences(of: "\\ ", with: " ");
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
        
        let formatted: String = formatter.string(from: value as NSNumber) ?? "n/a";
        return formatted + " GB";
    }
        
    static func getParentDir(_ path: String) -> String {
        guard let lastSlash = path.lastIndex(where: { char in char == "/"}) else { return path };
        return path.substring(to: lastSlash);
    }
}
