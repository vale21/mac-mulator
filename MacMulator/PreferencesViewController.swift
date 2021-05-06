//
//  PreferencesViewController.swift
//  MacMulator
//
//  Created by Vale on 22/04/21.
//

import Cocoa

class PreferencesViewController: NSViewController, NSTextFieldDelegate {
    
    @IBOutlet weak var vmFolderField: NSTextField!
    @IBOutlet weak var qemuFolderField: NSTextField!
    @IBOutlet weak var vmFolderButton: NSButton!
    @IBOutlet weak var qemuFolderButton: NSButton!
    
    var userDefaults: UserDefaults = UserDefaults.standard;
    
    override func viewWillAppear() {
        vmFolderField.stringValue = Utils.unescape(userDefaults.string(forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH)!);
        qemuFolderField.stringValue = Utils.unescape(userDefaults.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!);
    }
    
    @IBAction func searchFolder(_ sender: Any) {
        Utils.showDirectorySelector(uponSelection: {
            panel in
            if sender as? NSObject == vmFolderButton {
                vmFolderField.stringValue = panel.url!.path;
                userDefaults.set(Utils.escape(vmFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH);
            } else if sender as? NSObject == qemuFolderButton {
                qemuFolderField.stringValue = panel.url!.path;
                userDefaults.set(Utils.escape(qemuFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH);
            }
            
        });
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSObject == vmFolderField {
            userDefaults.set(Utils.escape(vmFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH);
        } else if obj.object as? NSObject == qemuFolderField {
            userDefaults.set(Utils.escape(qemuFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH);
        }
    }
}
