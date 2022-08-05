//
//  NewDiskViewController.swift
//  MacMulator
//
//  Created by Vale on 23/02/21.
//

import Cocoa

class NewDiskViewController: NSViewController, NSTextFieldDelegate {
    
    enum Mode {
        case ADD
        case EDIT
    }
    
    @IBOutlet weak var titleField: NSTextField!
    @IBOutlet weak var diskSizeTextField: NSTextField!
    @IBOutlet weak var diskSizeStepper: NSStepper!
    @IBOutlet weak var diskSizeSlider: NSSlider!
    @IBOutlet weak var minDiskSizeLabel: NSTextField!
    @IBOutlet weak var maxDiskSizeLabel: NSTextField!
    @IBOutlet weak var useCow: NSButton!
    @IBOutlet weak var okButton: NSButton!
    
    var oldVirtualDrive: VirtualDrive?
    var newVirtualDrive: VirtualDrive?
    var isVirtualizaionFrameworkInUse: Bool = false
    
    var parentController: EditVMViewControllerHardware?;
    var isVisible: Bool = false;
    var mode: Mode = Mode.ADD;
    
    func setVirtualDrive(_ virtualDrive: VirtualDrive) {
        self.newVirtualDrive = virtualDrive;
        self.oldVirtualDrive = virtualDrive.clone();
    }

    func setMode(_ mode: Mode) {
        self.mode = mode;
    }
    
    func setparentController(_ parentController: EditVMViewControllerHardware) {
        self.parentController = parentController;
    }
    
    fileprivate func updateView() {
        if let parentController = self.parentController {
            if let virtualMachine = parentController.virtualMachine {
                if let newVirtualDrive = self.newVirtualDrive {
                    diskSizeSlider.intValue = newVirtualDrive.size;
                    diskSizeStepper.intValue = newVirtualDrive.size;
                    diskSizeTextField.intValue = newVirtualDrive.size

                    if (newVirtualDrive.format == QemuConstants.FORMAT_QCOW2) {
                        useCow.intValue = 1;
                    } else {
                        useCow.intValue = 0;
                    }
                    if (isVirtualizaionFrameworkInUse) {
                        useCow.isEnabled = false
                        useCow.toolTip = "This Virtual Machine is based on Apple Virtualization Framework. With this type of Virtual Machines Copy On Write is not yet supported."
                    }
                    
                    if (mode == Mode.ADD) {
                        titleField.stringValue = "Create new disk";
                    } else {
                        titleField.stringValue = "Edit " + newVirtualDrive.name;
                    }
                    
                    
                    let minDiskSize = Utils.getMinDiskSizeForSubType(virtualMachine.os, virtualMachine.subtype);
                    let maxDiskSize = Utils.getMaxDiskSizeForSubType(virtualMachine.os, virtualMachine.subtype);
                    
                    minDiskSizeLabel.stringValue = Utils.formatDisk(Int32(minDiskSize));
                    maxDiskSizeLabel.stringValue = Utils.formatDisk(Int32(maxDiskSize));
                    diskSizeStepper.minValue = Double(minDiskSize);
                    diskSizeStepper.maxValue = Double(maxDiskSize);
                    diskSizeSlider.minValue = Double(minDiskSize);
                    diskSizeSlider.maxValue = Double(maxDiskSize);
                }
            }
        }
    }
    
    @IBAction func cowCheckboxChanged(_ sender: Any) {
        if useCow.intValue == 1 {
            newVirtualDrive?.format = QemuConstants.FORMAT_QCOW2;
        } else {
            newVirtualDrive?.format = QemuConstants.FORMAT_RAW;
        }
    }

    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.dismiss(self);
    }
    
    @IBAction func sliderChanged(_ sender: Any) {
        if (sender as? NSObject == diskSizeSlider) {
            if let newVirtualDrive = self.newVirtualDrive {
                newVirtualDrive.size = diskSizeSlider.intValue;
                diskSizeTextField.intValue = diskSizeSlider.intValue;
                diskSizeStepper.intValue = diskSizeSlider.intValue;
            }
        }
    }
    
    @IBAction func stepperChanged(_ sender: Any) {
        if (sender as? NSObject == diskSizeStepper) {
            if let newVirtualDrive = self.newVirtualDrive {
                newVirtualDrive.size = diskSizeStepper.intValue
                diskSizeTextField.intValue = diskSizeStepper.intValue;
                diskSizeSlider.intValue = diskSizeStepper.intValue;
            }
        }
    }
    
    override func viewWillAppear() {
        updateView();
    }
    
    override func viewDidAppear() {
        isVisible = true;
    }
    
    override func viewDidDisappear() {
        isVisible = false;
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if (notification.object as! NSTextField) == diskSizeTextField && self.isVisible {
            if let newVirtualDrive = self.newVirtualDrive {
                let size = diskSizeTextField.intValue;
                newVirtualDrive.size = size;
                diskSizeStepper.intValue = size;
                diskSizeSlider.intValue = size;
                
                if let parentController = self.parentController {
                    if let virtualMachine = parentController.virtualMachine {
                        if size < Utils.getMinDiskSizeForSubType(virtualMachine.os, virtualMachine.subtype) || size > Utils.getMaxDiskSizeForSubType(virtualMachine.os, virtualMachine.subtype) {
                            diskSizeStepper.isEnabled = false;
                            diskSizeSlider.isEnabled = false;
                        } else {
                            diskSizeStepper.isEnabled = true;
                            diskSizeSlider.isEnabled = true;
                        }
                    }
                }
            }
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if (segue.identifier == MacMulatorConstants.CREATE_DISK_FILE_SEGUE) {
            if let newVirtualDrive = self.newVirtualDrive {
                let destinationController = segue.destinationController as! CreateDiskFileViewController;
                destinationController.setNewVirtualDrive(newVirtualDrive);
                destinationController.setOldVirtualDrive((mode == Mode.EDIT) ? oldVirtualDrive : nil);
                destinationController.setParentController(self);
            }
        }
    }
    
    func diskCreated() {
        if let newVirtualDrive = self.newVirtualDrive {
            if mode == Mode.ADD {
                parentController?.addVirtualDrive(newVirtualDrive);
            }
            else {
                parentController?.reloadDrives();
            }
        }
        self.dismiss(self);
    }
}
