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
    
    @IBOutlet weak var diskSizeTextField: NSTextField!
    @IBOutlet weak var diskSizeStepper: NSStepper!
    @IBOutlet weak var diskSizeSlider: NSSlider!
    @IBOutlet weak var useCow: NSButton!
    @IBOutlet weak var okButton: NSButton!
    
    var virtualDrive: VirtualDrive?
    var parentController: EditVMViewControllerHardware?;
    var isVisible: Bool = false;
    var mode: Mode = Mode.ADD;
    
    func setVirtualDrive(_ virtualDrive: VirtualDrive) {
        self.virtualDrive = virtualDrive;
    }

    func setMode(_ mode: Mode) {
        self.mode = mode;
    }
    
    func setparentController(_ parentController: EditVMViewControllerHardware) {
        self.parentController = parentController;
    }
    
    @IBAction func cowCheckboxChanged(_ sender: Any) {
        if useCow.intValue == 1 {
            virtualDrive?.format = QemuConstants.FORMAT_QCOW2;
        } else {
            virtualDrive?.format = QemuConstants.FORMAT_RAW;
        }
    }

    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.dismiss(self);
    }
    
    @IBAction func sliderChanged(_ sender: Any) {
        if (sender as? NSObject == diskSizeSlider) {
            if let virtualDrive = self.virtualDrive {
                virtualDrive.size = diskSizeSlider.intValue;
                diskSizeTextField.intValue = diskSizeSlider.intValue;
                diskSizeStepper.intValue = diskSizeSlider.intValue;
            }
        }
    }
    
    @IBAction func stepperChanged(_ sender: Any) {
        if (sender as? NSObject == diskSizeStepper) {
            if let virtualDrive = self.virtualDrive {
                virtualDrive.size = diskSizeStepper.intValue
                diskSizeTextField.intValue = diskSizeStepper.intValue;
                diskSizeSlider.intValue = diskSizeStepper.intValue;
            }
        }
    }
    
    override func viewWillAppear() {
        if let virtualDrive = self.virtualDrive {
            diskSizeSlider.intValue = virtualDrive.size;
            diskSizeStepper.intValue = virtualDrive.size;
            diskSizeTextField.intValue = virtualDrive.size

            if (virtualDrive.format == QemuConstants.FORMAT_QCOW2) {
                useCow.intValue = 1;
            } else {
                useCow.intValue = 0;
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
            if let virtualDrive = self.virtualDrive {
                virtualDrive.size = diskSizeTextField.intValue;
                diskSizeStepper.intValue = diskSizeTextField.intValue;
                diskSizeSlider.intValue = diskSizeTextField.intValue;
            }
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if (segue.identifier == MacMulatorConstants.CREATE_DISK_FILE_SEGUE) {
            if let virtualDrive = self.virtualDrive {
                let destinationController = segue.destinationController as! CreateDiskFileViewController;
                destinationController.setVirtualDrive(virtualDrive);
                destinationController.setparentController(self);
            }
        }
    }
    
    func diskCreated() {
        if let virtualDrive = self.virtualDrive {
            if mode == Mode.ADD {
                parentController?.addVirtualDrive(virtualDrive);
            }
            else {
                parentController?.reloadDrives();
            }
        }
        self.dismiss(self);
    }
}
