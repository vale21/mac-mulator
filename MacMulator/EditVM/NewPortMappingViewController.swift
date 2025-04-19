//
//  NewPortMappingViewController.swift
//  MacMulator
//
//  Created by Vale on 04/08/22.
//

import Cocoa

class NewPortMappingViewController: NSViewController, NSTextFieldDelegate {
    enum Mode {
        case ADD
        case EDIT
    }

    @IBOutlet var nameField: NSTextField!
    @IBOutlet var titleField: NSTextField!
    @IBOutlet var virtualMachinePortField: NSTextField!
    @IBOutlet var virtualMachinePortStepper: NSStepper!
    @IBOutlet var hostMacPortField: NSTextField!
    @IBOutlet var hostMacPortStepper: NSStepper!

    var parentController: EditVMViewControllerNetwork?
    var portMapping: PortMapping = .init(name: "", vmPort: Utils.random(digits: 4), hostPort: Utils.random(digits: 4))
    var origPortMapping: PortMapping?
    var mode: Mode = .ADD

    func setParentController(_ parentController: EditVMViewControllerNetwork) {
        self.parentController = parentController
    }

    func setPortmapping(_ portMapping: PortMapping) {
        origPortMapping = portMapping

        self.portMapping.name = origPortMapping!.name
        self.portMapping.vmPort = origPortMapping!.vmPort
        self.portMapping.hostPort = origPortMapping!.hostPort
    }

    func setMode(_ mode: Mode) {
        self.mode = mode
    }

    override func viewWillAppear() {
        let portNumberFormatter = NumberFormatter()
        portNumberFormatter.hasThousandSeparators = false

        hostMacPortField.formatter = portNumberFormatter
        virtualMachinePortField.formatter = portNumberFormatter

        updateView()
    }

    fileprivate func updateView() {
        nameField.stringValue = portMapping.name
        virtualMachinePortStepper.intValue = portMapping.vmPort
        virtualMachinePortField.intValue = portMapping.vmPort
        hostMacPortStepper.intValue = portMapping.hostPort
        hostMacPortField.intValue = portMapping.hostPort

        if mode == Mode.ADD {
            titleField.stringValue = NSLocalizedString("NewPortMappingViewController.createMapping", comment: "")
        } else {
            titleField.stringValue = String(format: NSLocalizedString("NewPortMappingViewController.editMapping", comment: ""), portMapping.name)
        }
    }

    @IBAction func stepperChanged(_ sender: Any) {
        if sender as? NSObject == virtualMachinePortStepper {
            portMapping.vmPort = virtualMachinePortStepper.intValue
            virtualMachinePortField.intValue = virtualMachinePortStepper.intValue
        }
        if sender as? NSObject == hostMacPortStepper {
            portMapping.hostPort = hostMacPortStepper.intValue
            hostMacPortField.intValue = hostMacPortStepper.intValue
        }
    }

    @IBAction func okButtonPressed(_: Any) {
        if mode == Mode.ADD {
            parentController?.addPortmapping(portMapping)
        } else {
            origPortMapping?.name = portMapping.name
            origPortMapping?.vmPort = portMapping.vmPort
            origPortMapping?.hostPort = portMapping.hostPort

            parentController?.reloadPortMappings()
        }
        dismiss(self)
    }

    @IBAction func cancelButtonPressed(_: Any) {
        dismiss(self)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if (notification.object as! NSTextField) === nameField {
            portMapping.name = nameField.stringValue
        } else if (notification.object as! NSTextField) === virtualMachinePortField {
            portMapping.vmPort = virtualMachinePortField.intValue
            virtualMachinePortStepper.intValue = virtualMachinePortField.intValue
        } else if (notification.object as! NSTextField) === hostMacPortField {
            portMapping.hostPort = hostMacPortField.intValue
            hostMacPortStepper.intValue = hostMacPortField.intValue
        }
    }
}
