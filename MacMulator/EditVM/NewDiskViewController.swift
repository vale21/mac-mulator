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
    @IBOutlet weak var useCow: NSButton!
    @IBOutlet weak var okButton: NSButton!
    
    var oldVirtualDrive: VirtualDrive?
    var newVirtualDrive: VirtualDrive?
    
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
        if let newVirtualDrive = self.newVirtualDrive {
            diskSizeSlider.intValue = newVirtualDrive.size;
            diskSizeStepper.intValue = newVirtualDrive.size;
            diskSizeTextField.intValue = newVirtualDrive.size

            if (newVirtualDrive.format == QemuConstants.FORMAT_QCOW2) {
                useCow.intValue = 1;
            } else {
                useCow.intValue = 0;
            }
            
            if (mode == Mode.ADD) {
                titleField.stringValue = "Create new disk";
            } else {
                titleField.stringValue = "Edit " + newVirtualDrive.name;
            }
        }
    }
    
    override func viewDidAppear() {
        isVisible = true;
    }
    
    override func viewDidDisappear() {
        isVisible = false;
    }
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if control == diskSizeTextField {
            let size = diskSizeTextField.intValue;
            if (size >= 1 && size <= 2000) {
                return true;
            }
        }
        return false;
    }
    
    func controlTextDidEndEditing(_ notification: Notification) {
        if (notification.object as! NSTextField) == diskSizeTextField && self.isVisible {
            if let newVirtualDrive = self.newVirtualDrive {
                newVirtualDrive.size = diskSizeTextField.intValue;
                diskSizeStepper.intValue = diskSizeTextField.intValue;
                diskSizeSlider.intValue = diskSizeTextField.intValue;
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
