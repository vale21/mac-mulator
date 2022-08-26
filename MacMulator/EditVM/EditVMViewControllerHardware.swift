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
    @IBOutlet weak var openImageButton: NSButton!
    @IBOutlet weak var createNewDiskButton: NSButton!
    
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
                        if virtualDrive.path == path {
                            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.informational, message: "You already have configured image at path " + path + " to be loaded in MacMulator.");
                            return;
                        }
                    }
                    
                    // no existing drive found
                    var newDrive: VirtualDrive;
                    if path.hasSuffix(QemuConstants.FORMAT_QCOW2) || path.hasSuffix(MacMulatorConstants.DISK_EXTENSION) {
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_DISK + "-" + String(Utils.computeNextDriveIndex(virtualMachine, QemuConstants.MEDIATYPE_DISK)),
                            format: QemuConstants.FORMAT_UNKNOWN,
                            mediaType: QemuConstants.MEDIATYPE_DISK,
                            size: 0);
                    } else if path.hasSuffix(MacMulatorConstants.EFI_EXTENSION) {
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_EFI + "-" + String(Utils.computeNextDriveIndex(virtualMachine, QemuConstants.MEDIATYPE_EFI)),
                            format: QemuConstants.FORMAT_RAW,
                            mediaType: QemuConstants.MEDIATYPE_EFI,
                            size: 0);
                    } else if virtualMachine.architecture == QemuConstants.ARCH_X64 && virtualMachine.os == QemuConstants.OS_MAC {
                        // Install media is a USB stick
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_USB + "-0",
                            format: QemuConstants.FORMAT_RAW,
                            mediaType: QemuConstants.MEDIATYPE_USB,
                            size: 0);
                    } else if Utils.isVirtualizationFrameworkPreferred(virtualMachine) && virtualMachine.os == QemuConstants.OS_MAC {
                        // Install media is a IPSW image
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_IPSW + "-0",
                            format: QemuConstants.FORMAT_RAW,
                            mediaType: QemuConstants.MEDIATYPE_IPSW,
                            size: 0);
                    } else {
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_CDROM + "-" + String(Utils.computeNextDriveIndex(virtualMachine, QemuConstants.MEDIATYPE_CDROM)),
                            format: QemuConstants.FORMAT_RAW,
                            mediaType: QemuConstants.MEDIATYPE_CDROM,
                            size: 0);
                    }
                    virtualMachine.addVirtualDrive(newDrive);
                
                    virtualMachine.writeToPlist();
                    updateView()
                }
            }
        });
    }
    
    @IBAction func deleteVirtualDrive(_ sender: Any) {
        if let virtualMachine = self.virtualMachine {
            let row = drivesTableView.row(for: sender as! NSView);
            let index = Utils.computeDrivesTableIndex(virtualMachine, row);
            let drive = virtualMachine.drives[index];
            if drive.mediaType == QemuConstants.MEDIATYPE_CDROM || drive.mediaType == QemuConstants.MEDIATYPE_USB || drive.mediaType == QemuConstants.MEDIATYPE_IPSW {
                self.removeVirtualDrive(row, index);
            } else {
                Utils.showPrompt(window: self.view.window!, style: NSAlert.Style.informational, message: "Are you sure you want to remove Virtual Drive " + drive.name + "? This operation is not reversible.", completionHandler: { response in
                    if response.rawValue == Utils.ALERT_RESP_OK {
                        self.removeVirtualDrive(row, index);
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
    
    fileprivate func removeVirtualDrive(_ row: Int, _ index: Int) {
        if let virtualMachine = self.virtualMachine {
            self.drivesTableView.removeRows(at: IndexSet(integer: IndexSet.Element(row)), withAnimation: NSTableView.AnimationOptions.slideUp);
            virtualMachine.drives.remove(at: index);
            virtualMachine.writeToPlist();
            self.updateView()
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
            
            let minMemory = Utils.getMinMemoryForSubType(virtualMachine.os, virtualMachine.subtype);
            let maxMemory = Utils.getMaxMemoryForSubType(virtualMachine.os, virtualMachine.subtype);
            
            minMemoryLabel.stringValue = Utils.formatMemory(Int32(minMemory));
            maxMemoryLabel.stringValue = Utils.formatMemory(Int32(maxMemory));
            memoryStepper.minValue = Double(minMemory);
            memoryStepper.maxValue = Double(maxMemory);
            memorySlider.minValue = Double(minMemory);
            memorySlider.maxValue = Double(maxMemory);
            
            if virtualMachine.memory < Utils.getMinMemoryForSubType(virtualMachine.os, virtualMachine.subtype) || virtualMachine.memory > Utils.getMaxMemoryForSubType(virtualMachine.os, virtualMachine.subtype) {
                memoryStepper.isEnabled = false;
                memorySlider.isEnabled = false;
            } else {
                memoryStepper.isEnabled = true;
                memorySlider.isEnabled = true;
            }
            
            drivesTableView.reloadData();
            
            if Utils.isVirtualizationFrameworkPreferred(virtualMachine) && Utils.findInstallDrive(virtualMachine.drives) != nil {
                openImageButton.isEnabled = false
                openImageButton.toolTip = "This Virtual Machine is based on Apple Virtualization Framework. With this type of Virtual Machines only one drive can be used at the moment."
            } else {
                openImageButton.isEnabled = true
            }
            
            if Utils.isVirtualizationFrameworkPreferred(virtualMachine) && Utils.findMainDrive(virtualMachine.drives) != nil {
                createNewDiskButton.isEnabled = false
                createNewDiskButton.toolTip = "This Virtual Machine is based on Apple Virtualization Framework. With this type of Virtual Machines only one drive can be used at the moment."
            } else {
                createNewDiskButton.isEnabled = true
            }
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let virtualMachine = self.virtualMachine {
            if (segue.identifier == MacMulatorConstants.NEW_DISK_SEGUE) {
                let diskName = QemuConstants.MEDIATYPE_DISK + "-" + String(Utils.computeNextDriveIndex(virtualMachine, QemuConstants.MEDIATYPE_DISK));
                let virtualDrive = VirtualDrive(path: virtualMachine.path, name: diskName, format: QemuConstants.FORMAT_QCOW2, mediaType: QemuConstants.MEDIATYPE_DISK, size: Int32(Utils.getDefaultDiskSizeForSubType(virtualMachine.os, virtualMachine.subtype)));
                
                let destinationController = segue.destinationController as! NewDiskViewController;
                destinationController.setVirtualDrive(virtualDrive);
                destinationController.setparentController(self);
                destinationController.isVirtualizaionFrameworkInUse = Utils.isVirtualizationFrameworkPreferred(virtualMachine)
            }
            if (segue.identifier == MacMulatorConstants.EDIT_DISK_SEGUE) {
                let destinationController = segue.destinationController as! NewDiskViewController;
                let driveTableRow: Int = drivesTableView.row(for: sender as! NSView)
                destinationController.setVirtualDrive(virtualMachine.drives[Utils.computeDrivesTableIndex(virtualMachine, driveTableRow)]);
                destinationController.setparentController(self);
                destinationController.setMode(NewDiskViewController.Mode.EDIT);
                destinationController.isVirtualizaionFrameworkInUse = Utils.isVirtualizationFrameworkPreferred(virtualMachine)
            }
            if (segue.identifier == MacMulatorConstants.SHOW_DRIVE_INFO_SEGUE) {
                let destinationController = segue.destinationController as! NSWindowController;
                let contentController = destinationController.contentViewController as! DriveInfoViewController;
                let driveTableRow: Int = drivesTableView.row(for: sender as! NSView)
                contentController.setVirtualDrive(virtualMachine.drives[Utils.computeDrivesTableIndex(virtualMachine, driveTableRow)]);
            }
        }
    }
    
    func addVirtualDrive(_ virtualDrive: VirtualDrive) {
        virtualMachine?.drives.append(virtualDrive);
        updateView()
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
                    
                    if memory < Utils.getMinMemoryForSubType(virtualMachine.os, virtualMachine.subtype) || memory > Utils.getMaxMemoryForSubType(virtualMachine.os, virtualMachine.subtype) {
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
        
        let drive = virtualMachine?.drives[index];
        
        if tableColumn?.identifier.rawValue == "Icon" {
            let cellView = cell as! DrivesTableIconCell;
            
            if drive?.mediaType == QemuConstants.MEDIATYPE_DISK {
                cellView.icon.image = NSImage(named: "HD Icon");
            } else if drive?.mediaType == QemuConstants.MEDIATYPE_CDROM {
                cellView.icon.image = NSImage(named: "CD Icon");
            } else if drive?.mediaType == QemuConstants.MEDIATYPE_USB || drive?.mediaType == QemuConstants.MEDIATYPE_IPSW {
                cellView.icon.image = NSImage(named: "USB Icon");
            }
        }
        
        if tableColumn?.identifier.rawValue == "Name" {
            let cellView = cell as! DrivesTableDriveNameCell;
            cellView.label.stringValue = drive?.name ?? "";
            cellView.toolTip = cellView.label.stringValue;
        }
        
        if tableColumn?.identifier.rawValue == "Type" {
            let cellView = cell as! DrivesTableDriveTypeCell;
            cellView.label.stringValue = QemuUtils.getDriveTypeDescription(drive?.mediaType ?? "");
            cellView.toolTip = cellView.label.stringValue;
        }
        
        if tableColumn?.identifier.rawValue == "Size" {
            let cellView = cell as! DrivesTableDriveSizeCell;
            cellView.label.stringValue = Utils.formatDisk(drive?.size ?? 0);
            cellView.toolTip = cellView.label.stringValue;
        }
        
        if tableColumn?.identifier.rawValue == "Path" {
            let cellView = cell as! DrivesTableDrivePathCell;
            cellView.label.stringValue = Utils.unescape(drive?.path ?? "");
            cellView.toolTip = cellView.label.stringValue;
        }
        
        if (tableColumn?.identifier.rawValue == "Buttons") {
            let cellView = cell as! DrivesTableButtonsCell;
            if (drive?.mediaType == QemuConstants.MEDIATYPE_CDROM || drive?.mediaType == QemuConstants.MEDIATYPE_USB || drive?.mediaType == QemuConstants.MEDIATYPE_IPSW) {
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
        return Utils.computeDrivesTableSize(virtualMachine);
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30.0;
    }
}


