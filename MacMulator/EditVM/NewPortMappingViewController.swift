//
//  NewPortMappingViewController.swift
//  MacMulator
//
//  Created by Vale on 04/08/22.
//

import Cocoa

protocol PortMappingsEditor: AnyObject {
    var virtualMachine: VirtualMachine? { get }
    func addPortmapping(_ portMapping: PortMapping)
    func reloadPortMappings()
}

class NewPortMappingViewController: NSViewController, NSTextFieldDelegate {
    enum Mode {
        case ADD
        case EDIT
    }

    @IBOutlet var titleField: NSTextField!
    @IBOutlet var nameLabel: NSTextField!
    @IBOutlet var nameField: NSTextField!
    @IBOutlet var virtualMachinePortLabel: NSTextField!
    @IBOutlet var virtualMachinePortField: NSTextField!
    @IBOutlet var virtualMachinePortStepper: NSStepper!
    @IBOutlet var hostMacPortLabel: NSTextField!
    @IBOutlet var hostMacPortField: NSTextField!
    @IBOutlet var hostMacPortStepper: NSStepper!

    var parentController: PortMappingsEditor?
    var portMapping: PortMapping = .init(name: "", vmPort: Utils.random(digits: 4), hostPort: Utils.random(digits: 4))
    var origPortMapping: PortMapping?
    var mode: Mode = .ADD

    func setParentController(_ parentController: PortMappingsEditor) {
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
        if portMapping.hostPort != origPortMapping?.hostPort, let message = hostPortConflictMessage(portMapping.hostPort) {
            Utils.showPrompt(window: view.window!, style: NSAlert.Style.warning, message: message, completionHandler: { response in
                if response.rawValue == Utils.ALERT_RESP_OK {
                    self.savePortMapping()
                }
            }, virtualMachine: parentController?.virtualMachine)
            return
        }
        savePortMapping()
    }

    @IBAction func cancelButtonPressed(_: Any) {
        dismiss(self)
    }

    override func viewWillAppear() {
        nameLabel.stringValue = NSLocalizedString("NewPortMappingViewController.nameLabel", comment: "")
        virtualMachinePortLabel.stringValue = NSLocalizedString("NewPortMappingViewController.virtualMachinePortLabel", comment: "")
        hostMacPortLabel.stringValue = NSLocalizedString("NewPortMappingViewController.hostMacPortLabel", comment: "")

        let portNumberFormatter = NumberFormatter()
        portNumberFormatter.hasThousandSeparators = false

        hostMacPortField.formatter = portNumberFormatter
        virtualMachinePortField.formatter = portNumberFormatter

        updateView()
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

    private func updateView() {
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

    private func savePortMapping() {
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

    private func hostPortConflictMessage(_ hostPort: Int32) -> String? {
        // The VM being edited comes first: the workspace list may hold another copy of it, with the old mappings
        let currentVM = parentController?.virtualMachine
        let virtualMachines = (currentVM.map { [$0] } ?? []) + Utils.workspaceVirtualMachines().filter { $0.id != currentVM?.id }

        for virtualMachine in virtualMachines {
            if let mapping = virtualMachine.portMappings?.first(where: { $0 !== origPortMapping && $0.hostPort == hostPort }) {
                if virtualMachine === currentVM {
                    return String(format: NSLocalizedString("NewPortMappingViewController.hostPortUsedBySameVM", comment: ""), Int(hostPort), mapping.name)
                }
                return String(format: NSLocalizedString("NewPortMappingViewController.hostPortUsedByVM", comment: ""), Int(hostPort), mapping.name, virtualMachine.displayName)
            }
        }
        if Utils.isHostPortInUse(hostPort) {
            return String(format: NSLocalizedString("NewPortMappingViewController.hostPortInUse", comment: ""), Int(hostPort))
        }
        return nil
    }
}
