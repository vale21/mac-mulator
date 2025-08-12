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

    @IBOutlet var titleField: NSTextField!
    @IBOutlet var diskSizeLabel: NSTextField!
    @IBOutlet var diskSizeTextField: NSTextField!
    @IBOutlet var diskSizeStepper: NSStepper!
    @IBOutlet var diskSizeSlider: NSSlider!
    @IBOutlet var minDiskSizeLabel: NSTextField!
    @IBOutlet var maxDiskSizeLabel: NSTextField!
    @IBOutlet var useCow: NSButton!
    @IBOutlet var cowDescriptionLabel: NSTextField!
    @IBOutlet var okButton: NSButton!

    var oldVirtualDrive: VirtualDrive?
    var newVirtualDrive: VirtualDrive?

    var parentController: EditVMViewControllerHardware?
    var isVisible: Bool = false
    var mode: Mode = .ADD

    func setVirtualDrive(_ virtualDrive: VirtualDrive) {
        newVirtualDrive = virtualDrive
        oldVirtualDrive = virtualDrive.clone()
    }

    func setMode(_ mode: Mode) {
        self.mode = mode
    }

    func setparentController(_ parentController: EditVMViewControllerHardware) {
        self.parentController = parentController
    }

    fileprivate func updateView() {
        if let parentController {
            if let virtualMachine = parentController.virtualMachine {
                if let newVirtualDrive {
                    diskSizeSlider.intValue = newVirtualDrive.size
                    diskSizeStepper.intValue = newVirtualDrive.size
                    diskSizeTextField.intValue = newVirtualDrive.size

                    if virtualMachine.type == MacMulatorConstants.APPLE_VM {
                        if Utils.isAsifSupported(virtualMachine) {
                            useCow.title = "Use ASIF format"
                            cowDescriptionLabel.stringValue = "The ASIF image format greatly reduces the amount of disk space used by the drive, and it is highly recommended"
                            if newVirtualDrive.format == QemuConstants.FORMAT_ASIF {
                                useCow.intValue = 1
                            } else {
                                useCow.intValue = 0
                            }
                            if mode == Mode.EDIT {
                                useCow.isEnabled = false
                                useCow.toolTip = "Updating this property on an existing drive is not supported at the moment"
                            }
                        } else {
                            newVirtualDrive.format = QemuConstants.FORMAT_RAW

                            useCow.intValue = 0
                            useCow.isEnabled = false
                            cowDescriptionLabel.stringValue = NSLocalizedString("NewDiskViewController.cowNotSupported", comment: "")
                            useCow.toolTip = NSLocalizedString("NewDiskViewController.cowNotSupported", comment: "")
                        }

                    } else {
                        cowDescriptionLabel.stringValue = NSLocalizedString("NewDiskViewController.cowDescriptionLabel", comment: "")
                        if newVirtualDrive.format == QemuConstants.FORMAT_QCOW2 {
                            useCow.intValue = 1
                        } else {
                            useCow.intValue = 0
                        }
                    }

                    if mode == Mode.ADD {
                        titleField.stringValue = NSLocalizedString("NewDiskViewController.createDisk", comment: "")
                    } else {
                        titleField.stringValue = String(format: NSLocalizedString("NewDiskViewController.editDisk", comment: ""), newVirtualDrive.name)
                    }

                    let minDiskSize = Utils.getMinDiskSizeForSubType(virtualMachine.os, virtualMachine.subtype)
                    let maxDiskSize = Utils.getMaxDiskSizeForSubType(virtualMachine.os, virtualMachine.subtype)

                    minDiskSizeLabel.stringValue = Utils.formatDisk(Int32(minDiskSize))
                    maxDiskSizeLabel.stringValue = Utils.formatDisk(Int32(maxDiskSize))
                    diskSizeStepper.minValue = Double(minDiskSize)
                    diskSizeStepper.maxValue = Double(maxDiskSize)
                    diskSizeSlider.minValue = Double(minDiskSize)
                    diskSizeSlider.maxValue = Double(maxDiskSize)
                }
            }
        }
    }

    @IBAction func cowCheckboxChanged(_: Any) {
        newVirtualDrive?.format = QemuConstants.FORMAT_RAW
        
        if useCow.intValue == 1 {
            if let parentController {
                if let virtualMachine = parentController.virtualMachine {
                    if Utils.isAsifSupported(virtualMachine) {
                        newVirtualDrive?.format = QemuConstants.FORMAT_ASIF
                    } else {
                        newVirtualDrive?.format = QemuConstants.FORMAT_QCOW2
                    }
                }
            }
        }
    }

    @IBAction func cancelButtonPressed(_: Any) {
        dismiss(self)
    }

    @IBAction func sliderChanged(_ sender: Any) {
        if sender as? NSObject == diskSizeSlider {
            if let newVirtualDrive {
                newVirtualDrive.size = diskSizeSlider.intValue
                diskSizeTextField.intValue = diskSizeSlider.intValue
                diskSizeStepper.intValue = diskSizeSlider.intValue
            }
        }
    }

    @IBAction func stepperChanged(_ sender: Any) {
        if sender as? NSObject == diskSizeStepper {
            if let newVirtualDrive {
                newVirtualDrive.size = diskSizeStepper.intValue
                diskSizeTextField.intValue = diskSizeStepper.intValue
                diskSizeSlider.intValue = diskSizeStepper.intValue
            }
        }
    }

    override func viewWillAppear() {
        diskSizeTextField.stringValue = NSLocalizedString("NewDiskViewController.diskSizeTextField", comment: "")
        useCow.title = NSLocalizedString("NewDiskViewController.useCow", comment: "")
        cowDescriptionLabel.stringValue = NSLocalizedString("NewDiskViewController.cowDescriptionLabel", comment: "")

        updateView()
    }

    override func viewDidAppear() {
        isVisible = true
    }

    override func viewDidDisappear() {
        isVisible = false
    }

    func controlTextDidChange(_ notification: Notification) {
        if (notification.object as! NSTextField) == diskSizeTextField, isVisible {
            if let newVirtualDrive {
                let size = diskSizeTextField.intValue
                newVirtualDrive.size = size
                diskSizeStepper.intValue = size
                diskSizeSlider.intValue = size

                if let parentController {
                    if let virtualMachine = parentController.virtualMachine {
                        if size < Utils.getMinDiskSizeForSubType(virtualMachine.os, virtualMachine.subtype) || size > Utils.getMaxDiskSizeForSubType(virtualMachine.os, virtualMachine.subtype) {
                            diskSizeStepper.isEnabled = false
                            diskSizeSlider.isEnabled = false
                        } else {
                            diskSizeStepper.isEnabled = true
                            diskSizeSlider.isEnabled = true
                        }
                    }
                }
            }
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender _: Any?) {
        if segue.identifier == MacMulatorConstants.CREATE_DISK_FILE_SEGUE {
            if let newVirtualDrive {
                let destinationController = segue.destinationController as! CreateDiskFileViewController
                destinationController.setNewVirtualDrive(newVirtualDrive)
                destinationController.setOldVirtualDrive((mode == Mode.EDIT) ? oldVirtualDrive : nil)
                destinationController.setParentController(self)
                destinationController.isVirtualizaionFrameworkInUse = false
                if let parentController {
                    if let virtualMachine = parentController.virtualMachine {
                        destinationController.isVirtualizaionFrameworkInUse = virtualMachine.type == MacMulatorConstants.APPLE_VM
                    }
                }
            }
        }
    }

    func diskCreated() {
        if let newVirtualDrive {
            if mode == Mode.ADD {
                parentController?.addVirtualDrive(newVirtualDrive)
            } else {
                parentController?.reloadDrives()
            }
        }
        dismiss(self)
    }
}
