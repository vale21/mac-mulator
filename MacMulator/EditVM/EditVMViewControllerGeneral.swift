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
    @IBOutlet weak var bootOrderLabel: NSTextField!
    @IBOutlet weak var bootOrderView: NSScrollView!
    @IBOutlet weak var bootOrderTable: NSTableView!
    @IBOutlet weak var resolutionTable: NSTableView!
    @IBOutlet weak var resolutionView: NSScrollView!
    @IBOutlet weak var resolutionLabelTop: NSTextField!
    @IBOutlet weak var resolutionlabelSide: NSTextField!
    
    var virtualMachine: VirtualMachine?;
    let accountPasteboardType = NSPasteboard.PasteboardType.string;
    var updating = false
    var currentResolution:[Int] = []
        
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        updateView()
        currentResolution = Utils.getResolutionElements(vm.displayResolution)
    }
    
    override func viewWillAppear() {
        updateView();
    }
    
    fileprivate func selectBootDrive(_ virtualMachine: VirtualMachine) {
        if virtualMachine.architecture == QemuConstants.ARCH_X64 || virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
            let defaultBootMode = Utils.getBootModeForSubType(virtualMachine.os, virtualMachine.subtype)
            let index = QemuConstants.ALL_BOOT_MODES.firstIndex(of: virtualMachine.bootMode ?? defaultBootMode) ?? 0
            bootOrderTable.selectRowIndexes(IndexSet(integer: IndexSet.Element(index)), byExtendingSelection: false)
        } else {
            var i = 0;
            for drive in virtualMachine.drives {
                if drive.isBootDrive {
                    bootOrderTable.selectRowIndexes(IndexSet(integer: IndexSet.Element(i)), byExtendingSelection: false)
                    return
                }
                i += 1
            }
            bootOrderTable.selectRowIndexes(IndexSet(integer: IndexSet.Element(i)), byExtendingSelection: false)
        }
    }
    
    func updateView() {
        if let virtualMachine = self.virtualMachine {
            updating = true
            vmType.stringValue = virtualMachine.os
            vmSubType.stringValue = virtualMachine.subtype

            vmName.stringValue = virtualMachine.displayName
            vmDescription.string = virtualMachine.description
            
            if virtualMachine.type == MacMulatorConstants.APPLE_VM {
                bootOrderLabel.isHidden = true
                bootOrderTable.isHidden = true
                bootOrderView.isHidden = true
                
                resolutionView.setFrameSize(NSSize(width: 464, height: 165))
                resolutionTable.setFrameSize(NSSize(width: 464, height: 165))
                resolutionLabelTop.isHidden = true
                resolutionlabelSide.isHidden = false
                
            } else {
                bootOrderLabel.isHidden = false
                bootOrderTable.isHidden = false
                bootOrderView.isHidden = false
                
                resolutionView.setFrameSize(NSSize(width: 218, height: 141))
                resolutionTable.setFrameSize(NSSize(width: 218, height: 141))
                resolutionLabelTop.isHidden = false
                resolutionlabelSide.isHidden = true
            }
            
            if virtualMachine.architecture == QemuConstants.ARCH_X64 || virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
                bootOrderLabel.stringValue = NSLocalizedString("QemuConstants.bootMode", comment: "")
            } else {
                bootOrderLabel.stringValue = NSLocalizedString("QemuConstants.bootDrive", comment: "")
            }
                        
            bootOrderTable.reloadData()
            resolutionTable.reloadData()
            
            selectBootDrive(virtualMachine)
            resolutionTable.selectRowIndexes(IndexSet(integer: IndexSet.Element(0)), byExtendingSelection: false)
            updating = false
            
            if virtualMachine.os == QemuConstants.OS_IOS {
                resolutionTable.isHidden = true
            }
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if let virtualMachine = self.virtualMachine {
            if tableView == bootOrderTable {
                if virtualMachine.architecture == QemuConstants.ARCH_X64 || virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
                    return QemuConstants.ALL_BOOT_MODES.count
                } else {
                    return Utils.computeDrivesTableSize(virtualMachine)
                }
            }
            if tableView == resolutionTable {
                return QemuConstants.ALL_RESOLUTIONS_DESC.count + 1
            }
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSView();
        
        if let virtualMachine = self.virtualMachine {
            if tableView == bootOrderTable {
                if virtualMachine.architecture == QemuConstants.ARCH_X64 || virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
                    cell.addSubview(NSTextField(labelWithString: QemuConstants.ALL_BOOT_MODES_DESC[QemuConstants.ALL_BOOT_MODES[row]]!))
                } else {
                    cell.addSubview(NSTextField(labelWithString: getDriveDescription(virtualMachine, Utils.computeDrivesTableIndex(virtualMachine, row))));
                }
            }
            
            if tableView == resolutionTable {
                if row == 0 {
                    cell.addSubview(NSTextField(labelWithString: Utils.getCustomScreenSizeDesc(width: currentResolution[0], heigh: currentResolution[1])))
                } else {
                    cell.addSubview(NSTextField(labelWithString: QemuConstants.ALL_RESOLUTIONS_DESC[QemuConstants.ALL_RESOLUTIONS[row-1]]!));
                }
            }
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
        return true
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
        if !updating {
            if ((notification.object as! NSTableView) == bootOrderTable) {
                if let virtualMachine = self.virtualMachine {
                    let row = bootOrderTable.selectedRow
                    if virtualMachine.architecture == QemuConstants.ARCH_X64 || virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
                        if row >= 0 && row < QemuConstants.ALL_BOOT_MODES.count {
                            virtualMachine.bootMode = QemuConstants.ALL_BOOT_MODES[row]
                        }
                    } else {
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
                
            }
            if ((notification.object as! NSTableView) == resolutionTable) {
                if resolutionTable.selectedRow > 0 {
                    virtualMachine?.displayResolution = QemuConstants.ALL_RESOLUTIONS[resolutionTable.selectedRow - 1]
                    virtualMachine?.displayOrigin = QemuConstants.ORIGIN
                }
            }
        }
    }
}


