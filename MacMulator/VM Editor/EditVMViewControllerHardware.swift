//
//  GeneralEditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewControllerHardware: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    let supportedArchitectures: [String:String] = [
        QemuConstants.ARCH_X64: "Intel/AMD 64bit",
        QemuConstants.ARCH_X86: "Intel/AMD 32bit",
        QemuConstants.ARCH_PPC: "PowerPc",
        QemuConstants.ARCH_ARM: "ARM",
        QemuConstants.ARCH_ARM64: "ARM 64bit",
        QemuConstants.ARCH_68K: "Motorola 68k"
    ];
    
    @IBOutlet weak var architectureComboBox: NSComboBox!
    @IBOutlet weak var cpusComboBox: NSComboBox!
    @IBOutlet weak var memoryTextView: NSTextField!
    @IBOutlet weak var memoryStepper: NSStepper!
    @IBOutlet weak var memorySlider: NSSlider!
    
    var virtualMachine: VirtualMachine?;
    
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
        
        updateView();
    }
    
    override func viewDidAppear() {
        updateView();
    }
    
    func updateView() {
        if let virtualMachine = self.virtualMachine {
            architectureComboBox.reloadData();
            architectureComboBox.selectItem(at: QemuConstants.ALL_ARCHITECTURES.firstIndex(of: virtualMachine.architecture) ?? -1);
            
            cpusComboBox.reloadData();
            cpusComboBox.selectItem(at: (virtualMachine.cpus - 1));
            
            memoryStepper.intValue = virtualMachine.memory;
            memorySlider.intValue = virtualMachine.memory;
            memoryTextView.stringValue = String(virtualMachine.memory);
        }
    }
    
    @IBAction func sliderChanged(_ sender: Any) {
        if (sender as? NSObject == memorySlider) {
            if let virtualMachine = self.virtualMachine {
                virtualMachine.memory = memorySlider.intValue
                memoryTextView.stringValue = String(virtualMachine.memory);
                memoryStepper.intValue = virtualMachine.memory;
            }
        }
    }
    
    @IBAction func stepperChanged(_ sender: Any) {
        if (sender as? NSObject == memoryStepper) {
            if let virtualMachine = self.virtualMachine {
                virtualMachine.memory = memoryStepper.intValue;
                memoryTextView.stringValue = String(virtualMachine.memory);
                memorySlider.intValue = virtualMachine.memory;
            }
        }
    }
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        if (comboBox == architectureComboBox) {
            return supportedArchitectures.count
        } else {
            if let virtualMachine = self.virtualMachine {
                return QemuConstants.MAX_CPUS[virtualMachine.architecture] ?? 0;
            }
        }
        return 0;
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if (comboBox == architectureComboBox) {
            return index >= 0 ? supportedArchitectures[QemuConstants.ALL_ARCHITECTURES[index]] : "";
        }
        return (index + 1);
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        if (notification.object as! NSComboBox) == architectureComboBox {
            if let virtualMachine = self.virtualMachine {
                virtualMachine.architecture = QemuConstants.ALL_ARCHITECTURES[architectureComboBox.indexOfSelectedItem];
            
                cpusComboBox.reloadData();
                cpusComboBox.selectItem(at: (virtualMachine.cpus - 1));
            }
        }
        else {
            if cpusComboBox.indexOfSelectedItem >= 0 {
                virtualMachine?.cpus = cpusComboBox.indexOfSelectedItem + 1;
            } else {
                virtualMachine?.cpus = 1;
            }
        }
    }
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if control == memoryTextView {
            let mem = memoryTextView.stringValue;
            let mem_num = Utils.toInt32WithAutoLocale(mem);
            if let memory = mem_num {
                if (memory >= 32 && memory <= 2048) {
                    return true;
                }
            }
        }
        return false;
    }
    
    func controlTextDidEndEditing(_ notification: Notification) {
        if (notification.object as! NSTextField) == memoryTextView {
            if let virtualMachine = self.virtualMachine {
                let mem = memoryTextView.stringValue;
                let mem_num = Utils.toInt32WithAutoLocale(mem);
                if let memory = mem_num {
                    virtualMachine.memory = memory;
                    memoryStepper.intValue = virtualMachine.memory;
                    memorySlider.intValue = virtualMachine.memory;
                }
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self);
        
        if tableColumn?.identifier.rawValue == "Type" {
            let cellView = cell as! DrivesTableDriveTypeCell;
            
            if virtualMachine?.drives[row].mediaType == QemuConstants.MEDIATYPE_DISK {
                cellView.label.stringValue = QemuConstants.HD;
            }
            if virtualMachine?.drives[row].mediaType == QemuConstants.MEDIATYPE_CDROM {
                cellView.label.stringValue = QemuConstants.CD;
            }
        }
        
        if tableColumn?.identifier.rawValue == "Size" {
            let cellView = cell as! DrivesTableDriveSizeCell;
            cellView.label.stringValue = Utils.formatDisk(virtualMachine?.drives[row].size ?? 0);
        }

        if tableColumn?.identifier.rawValue == "Path" {
            let cellView = cell as! DrivesTableDrivePathCell;
            cellView.label.stringValue = Utils.unescape(virtualMachine?.drives[row].path ?? "");
        }
        
        return cell;
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return virtualMachine?.drives.count ?? 0;
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30.0;
    }
}


