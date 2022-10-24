//
//  GeneralEditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewControllerGeneral: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSComboBoxDataSource, NSComboBoxDelegate, NSTextFieldDelegate, NSTextViewDelegate {

    @IBOutlet weak var vmType: NSComboBox!
    @IBOutlet weak var vmSubType: NSComboBox!
    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet var vmDescription: NSTextView!
    @IBOutlet weak var bootOrderTable: NSTableView!
    @IBOutlet weak var resolutionTable: NSTableView!

    var virtualMachine: VirtualMachine?;
    let accountPasteboardType = NSPasteboard.PasteboardType.string;
        
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
        updateView();
    }
    
    override func viewWillAppear() {
        updateView();
    }
    
    fileprivate func selectBootDrive(_ virtualMachine: VirtualMachine) {
        var i = 0;
        for drive in virtualMachine.drives {
            if drive.isBootDrive {
                bootOrderTable.selectRowIndexes(IndexSet(integer: IndexSet.Element(i)), byExtendingSelection: false);
                return;
            }
            i += 1;
        }
        bootOrderTable.selectRowIndexes(IndexSet(integer: IndexSet.Element(i)), byExtendingSelection: false);
    }
    
    func updateView() {
        if let virtualMachine = self.virtualMachine {
            vmType.stringValue = virtualMachine.os
            vmSubType.stringValue = virtualMachine.subtype

            vmName.stringValue = virtualMachine.displayName
            vmDescription.string = virtualMachine.description
            
            let rowIndex: Array<String>.Index = QemuConstants.ALL_RESOLUTIONS.firstIndex(of: virtualMachine.displayResolution)!
            resolutionTable.selectRowIndexes(IndexSet(integer: IndexSet.Element(rowIndex)), byExtendingSelection: false)
            
            bootOrderTable.reloadData()
            selectBootDrive(virtualMachine)
            
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == bootOrderTable {
            return Utils.computeDrivesTableSize(virtualMachine);
        }
        if tableView == resolutionTable {
            return QemuConstants.ALL_RESOLUTIONS_DESC.count;
        }
        return 0;
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSView();

        if let virtualMachine = self.virtualMachine {
            if tableView == bootOrderTable {
                let index = Utils.computeDrivesTableIndex(virtualMachine, row);
                let view = NSTextField(labelWithString: getDriveDescription(virtualMachine, index));
                cell.addSubview(view);
                if (virtualMachine.qemuBootLoader) {
                    view.textColor = NSColor.gray;
                } else {
                    view.textColor = NSColor.labelColor;
                }
            }
        }
        
        if tableView == resolutionTable {
            cell.addSubview(NSTextField(labelWithString: QemuConstants.ALL_RESOLUTIONS_DESC[QemuConstants.ALL_RESOLUTIONS[row]]!));
        }
        
        return cell;
    }
    
    fileprivate func getDriveDescription(_ vm: VirtualMachine, _ row: Int) -> String {
        if row == vm.drives.count {
            return "Network"
        } else {
            let drive = vm.drives[row];
            let type = QemuUtils.getDriveTypeDescription(drive.mediaType);
            let descr = " (" + type + (drive.size > 0 ? (" " + String(drive.size) + " GB)") : ")")
            return drive.name + descr;
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if tableView == bootOrderTable {
            return !(virtualMachine?.qemuBootLoader ?? true);
        }
        return true;
    }
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        if comboBox == vmType {
            return QemuConstants.supportedVMTypes.count;
        }
        return vmType == nil ? 1 : Utils.countSubTypes(vmType.stringValue);
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if comboBox == vmType {
            return index < 0 ? nil : QemuConstants.supportedVMTypes[index];
        }
        return vmType == nil ? 1 : Utils.getSubType(vmType.stringValue, index);
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        if notification.object as? NSComboBox == vmType {
            vmSubType.stringValue = Utils.getSubType(comboBox(vmType, objectValueForItemAt: vmType.indexOfSelectedItem) as? String, 0);
            vmSubType.reloadData();
            
            virtualMachine?.os = QemuConstants.supportedVMTypes[vmType.indexOfSelectedItem]
            virtualMachine?.subtype = Utils.getSubType(virtualMachine?.os, 0);
             
        } else {
            virtualMachine?.subtype = Utils.getSubType(virtualMachine?.os, vmSubType.indexOfSelectedItem);
        }
    }
    
    func controlTextDidChange(_ notification: Notification) {
        if ((notification.object as! NSTextField) == vmName) {
            virtualMachine?.displayName = vmName.stringValue;
        }
    }
    
    func textDidChange(_ notification: Notification) {
        if ((notification.object as? NSTextView) == vmDescription) {
            virtualMachine?.description = vmDescription.string;
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if ((notification.object as! NSTableView) == bootOrderTable) {
            if let virtualMachine = self.virtualMachine {
                let row = bootOrderTable.selectedRow;
                var i = 0;
                for drive in virtualMachine.drives {
                    if row == i {
                        drive.isBootDrive = true
                    } else {
                        drive.isBootDrive = false
                    }
                    i += 1;
                }
            }
            
        }
        if ((notification.object as! NSTableView) == resolutionTable) {
            virtualMachine?.displayResolution = QemuConstants.ALL_RESOLUTIONS[resolutionTable.selectedRow];
        }
    }
}


