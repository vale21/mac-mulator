//
//  GeneralEditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewControllerHardware: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
        
    @IBOutlet weak var architectureComboBox: NSComboBox!
    @IBOutlet weak var cpusComboBox: NSComboBox!
    @IBOutlet weak var memoryTextView: NSTextField!
    @IBOutlet weak var memoryStepper: NSStepper!
    @IBOutlet weak var memorySlider: NSSlider!
    @IBOutlet weak var minMemoryLabel: NSTextField!
    @IBOutlet weak var maxMemoryLabel: NSTextField!
    @IBOutlet weak var drivesTableView: NSTableView!
    
    var virtualMachine: VirtualMachine?;
    
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
        updateView();
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
    
    @IBAction func openImage(_ sender: Any) {
        Utils.showFileSelector(fileTypes: Utils.IMAGE_TYPES, uponSelection: { panel in
            if let path = panel.url?.path {
                if let virtualMachine = self.virtualMachine {
                    
                    for virtualDrive in virtualMachine.drives {
                        if virtualDrive.mediaType == QemuConstants.MEDIATYPE_CDROM && virtualDrive.path == path {
                            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.informational, message: "You already have configured image at path " + path + " to be loaded as a virtual CD/DVD drive.");
                            return;
                        }
                    }
                    
                    // no existing CD drive found
                    let virtualCD = VirtualDrive(
                        path: path,
                        name: QemuConstants.MEDIATYPE_CDROM + "-" + String(virtualMachine.drives.count),
                        format: QemuConstants.FORMAT_RAW,
                        mediaType: QemuConstants.MEDIATYPE_CDROM,
                        size: 0);
                    virtualMachine.addVirtualDrive(virtualCD);
                    virtualMachine.writeToPlist();
                    drivesTableView.reloadData();
                }
            }
        });
    }
    
    @IBAction func deleteVirtualDrive(_ sender: Any) {
        if let virtualMachine = self.virtualMachine {
            let row = drivesTableView.row(for: sender as! NSView);
            let drive = virtualMachine.drives[row];
            if drive.mediaType == QemuConstants.MEDIATYPE_CDROM {
                self.removeVirtualDrive(row);
            } else {
                Utils.showPrompt(window: self.view.window!, style: NSAlert.Style.informational, message: "Are you sure you want to remove Virtual Drive " + drive.name + "? This operation is not reversible.", completionHandler: { response in
                    if response.rawValue == Utils.ALERT_RESP_OK {
                        self.removeVirtualDrive(row);
                        do {
                            try FileManager.default.removeItem(atPath: drive.path);
                        } catch {
                            print(error.localizedDescription);
                        }
                    }
                });
            }
        }
    }
    
    fileprivate func removeVirtualDrive(_ row: Int) {
        if let virtualMachine = self.virtualMachine {
            self.drivesTableView.removeRows(at: IndexSet(integer: IndexSet.Element(row)), withAnimation: NSTableView.AnimationOptions.slideUp);
            virtualMachine.drives.remove(at: row);
            virtualMachine.writeToPlist();
        }
    }
    
    override func viewWillAppear() {
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
            
            let subtype: String = virtualMachine.subtype ?? Utils.getSubType(virtualMachine.os, 0);
            let minMemory = Utils.getMinMemoryForSubType(virtualMachine.os, subtype);
            let maxMemory = Utils.getMaxMemoryForSubType(virtualMachine.os, subtype);
            
            minMemoryLabel.stringValue = Utils.formatMemory(Int32(minMemory));
            maxMemoryLabel.stringValue = Utils.formatMemory(Int32(maxMemory));
            memoryStepper.minValue = Double(minMemory);
            memoryStepper.maxValue = Double(maxMemory);
            memorySlider.minValue = Double(minMemory);
            memorySlider.maxValue = Double(maxMemory);
            
            if virtualMachine.memory < Utils.getMinMemoryForSubType(virtualMachine.os, subtype) || virtualMachine.memory > Utils.getMaxMemoryForSubType(virtualMachine.os, subtype) {
                memoryStepper.isEnabled = false;
                memorySlider.isEnabled = false;
            } else {
                memoryStepper.isEnabled = true;
                memorySlider.isEnabled = true;
            }
            
            drivesTableView.reloadData();
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let virtualMachine = self.virtualMachine {
            if (segue.identifier == MacMulatorConstants.NEW_DISK_SEGUE) {
                let diskName = QemuConstants.MEDIATYPE_DISK + "-" + String(virtualMachine.drives.count);
                let virtualDrive = VirtualDrive(path: virtualMachine.path, name: diskName, format: QemuConstants.FORMAT_QCOW2, mediaType: QemuConstants.MEDIATYPE_DISK, size: Int32(Utils.getDefaultDiskSizeForSubType(virtualMachine.os, virtualMachine.subtype ?? Utils.getSubType(virtualMachine.os, 0))));
                
                let destinationController = segue.destinationController as! NewDiskViewController;
                destinationController.setVirtualDrive(virtualDrive);
                destinationController.setparentController(self);
            }
            if (segue.identifier == MacMulatorConstants.EDIT_DISK_SEGUE) {
                let destinationController = segue.destinationController as! NewDiskViewController;
                destinationController.setVirtualDrive(virtualMachine.drives[drivesTableView.row(for: sender as! NSView)]);
                destinationController.setparentController(self);
                destinationController.setMode(NewDiskViewController.Mode.EDIT);
            }
            if (segue.identifier == MacMulatorConstants.SHOW_DRIVE_INFO_SEGUE) {
                let destinationController = segue.destinationController as! NSWindowController;
                let contentController = destinationController.contentViewController as! DriveInfoViewController;
                
                contentController.setVirtualDrive(virtualMachine.drives[drivesTableView.row(for: sender as! NSView)]);
            }
        }
    }
    
    func addVirtualDrive(_ virtualDrive: VirtualDrive) {
        virtualMachine?.drives.append(virtualDrive);
        reloadDrives();
    }
    
    func reloadDrives() {
        self.drivesTableView.reloadData();
    }
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        if (comboBox == architectureComboBox) {
            return QemuConstants.ALL_ARCHITECTURES_DESC.count
        } else {
            if let virtualMachine = self.virtualMachine {
                return QemuConstants.MAX_CPUS[virtualMachine.architecture] ?? 0;
            }
        }
        return 0;
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if (comboBox == architectureComboBox) {
            return index >= 0 ? QemuConstants.ALL_ARCHITECTURES_DESC[QemuConstants.ALL_ARCHITECTURES[index]] : "";
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
    
    func controlTextDidEndEditing(_ notification: Notification) {
        if (notification.object as! NSTextField) == memoryTextView {
            if let virtualMachine = self.virtualMachine {
                let mem = memoryTextView.stringValue;
                let mem_num = Utils.toInt32WithAutoLocale(mem);
                if let memory = mem_num {
                    virtualMachine.memory = memory;
                    memoryStepper.intValue = virtualMachine.memory;
                    memorySlider.intValue = virtualMachine.memory;
                    
                    let subtype: String = virtualMachine.subtype ?? Utils.getSubType(virtualMachine.os, 0);
                    if memory < Utils.getMinMemoryForSubType(virtualMachine.os, subtype) || memory > Utils.getMaxMemoryForSubType(virtualMachine.os, subtype) {
                        memoryStepper.isEnabled = false;
                        memorySlider.isEnabled = false;
                    } else {
                        memoryStepper.isEnabled = true;
                        memorySlider.isEnabled = true;
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self);
        let index = Utils.computeDrivesTableIndex(virtualMachine, row);
        
        let vm = virtualMachine?.drives[index];
        
        if tableColumn?.identifier.rawValue == "Icon" {
            let cellView = cell as! DrivesTableIconCell;
            
            if vm?.mediaType == QemuConstants.MEDIATYPE_DISK {
                cellView.icon.image = NSImage(named: "HD Icon");
            }
            if vm?.mediaType == QemuConstants.MEDIATYPE_CDROM {
                cellView.icon.image = NSImage(named: "CD Icon");
            }
        }
        
        if tableColumn?.identifier.rawValue == "Name" {
            let cellView = cell as! DrivesTableDriveNameCell;
            cellView.label.stringValue = vm?.name ?? "";
            cellView.toolTip = cellView.label.stringValue;
        }
        
        if tableColumn?.identifier.rawValue == "Type" {
            let cellView = cell as! DrivesTableDriveTypeCell;
            cellView.label.stringValue = QemuUtils.getDriveTypeDescription(vm?.mediaType ?? "");
            cellView.toolTip = cellView.label.stringValue;
        }
        
        if tableColumn?.identifier.rawValue == "Size" {
            let cellView = cell as! DrivesTableDriveSizeCell;
            cellView.label.stringValue = Utils.formatDisk(vm?.size ?? 0);
            cellView.toolTip = cellView.label.stringValue;
        }
        
        if tableColumn?.identifier.rawValue == "Path" {
            let cellView = cell as! DrivesTableDrivePathCell;
            cellView.label.stringValue = Utils.unescape(vm?.path ?? "");
            cellView.toolTip = cellView.label.stringValue;
        }
        
        if (tableColumn?.identifier.rawValue == "Buttons") {
            let cellView = cell as! DrivesTableButtonsCell;
            if (vm?.mediaType == QemuConstants.MEDIATYPE_CDROM) {
                cellView.editButton.isEnabled = false;
                cellView.infoButton.isEnabled = false;
            } else {
                cellView.editButton.isEnabled = true;
                cellView.infoButton.isEnabled = true;
            }
        }
        
        return cell;
    }
    

    
    func numberOfRows(in tableView: NSTableView) -> Int {
        var size = 0;
        if let vm = virtualMachine {
            for drive in vm.drives {
                if drive.mediaType != QemuConstants.MEDIATYPE_EFI {
                    size += 1;
                }
            }
        }
        return size;
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30.0;
    }
}


