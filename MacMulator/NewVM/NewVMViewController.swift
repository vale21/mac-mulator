//
//  NewVMViewController.swift
//  MacMulator
//
//  Created by Vale on 19/04/21.
//

import Cocoa

class NewVMViewController : NSViewController, NSComboBoxDataSource, NSComboBoxDelegate {
    
    @IBOutlet weak var vmType: NSComboBox!
    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet var vmDescription: NSTextView!
    
    var virtualMachine: VirtualMachine?;
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return QemuConstants.supportedVMTypes.count;
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return QemuConstants.supportedVMTypes[index];
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        virtualMachine?.os = QemuConstants.supportedVMTypes[vmType.indexOfSelectedItem];
    }
    
    @IBAction func createVM(_ sender: Any) {
        self.view.window?.close();
    }
}
