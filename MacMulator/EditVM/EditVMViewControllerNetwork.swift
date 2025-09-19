//
//  EditVMViewControllerNetwork.swift
//  MacMulator
//
//  Created by Vale on 03/06/22.
//

import Cocoa

class EditVMViewControllerNetwork: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet var networkAdapterLabel: NSTextField!
    @IBOutlet var networkAdapterComboBox: NSComboBox!
    @IBOutlet var portMappingsLabel: NSTextField!
    @IBOutlet var portMappingsDescription: NSTextField!
    @IBOutlet var mappingsTableView: NSTableView!
    @IBOutlet var createMappingButton: NSButton!

    var virtualMachine: VirtualMachine?

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        updateView()
    }

    override func viewWillAppear() {
        networkAdapterLabel.stringValue = NSLocalizedString("EditVMViewControllerNetwork.networkAdapterLabel", comment: "")
        portMappingsLabel.stringValue = NSLocalizedString("EditVMViewControllerNetwork.portMappingsLabel", comment: "")
        portMappingsDescription.stringValue = NSLocalizedString("EditVMViewControllerNetwork.portMappingsDescription", comment: "")
        createMappingButton.title = NSLocalizedString("EditVMViewControllerNetwork.createMappingButton", comment: "")

        for column in mappingsTableView.tableColumns {
            if column.identifier.rawValue == "Name" {
                column.headerCell.title = NSLocalizedString("EditVMViewControllerNetwork.mappingsTableColumnName", comment: "")
            }
            if column.identifier.rawValue == "VM" {
                column.headerCell.title = NSLocalizedString("EditVMViewControllerNetwork.mappingsTableColumnVM", comment: "")
            }
            if column.identifier.rawValue == "Host" {
                column.headerCell.title = NSLocalizedString("EditVMViewControllerNetwork.mappingsTableColumnHost", comment: "")
            }
        }

        updateView()
    }

    func updateView() {
        if let virtualMachine {
            networkAdapterComboBox.reloadData()
            networkAdapterComboBox.selectItem(at: QemuConstants.ALL_NETWORK_ADAPTERS.firstIndex(of: virtualMachine.networkDevice ?? Utils.getNetworkForSubType(virtualMachine.os, virtualMachine.subtype, virtualMachine.architecture)) ?? -1)

            mappingsTableView.reloadData()
        }
    }

    func reloadPortMappings() {
        mappingsTableView.reloadData()
    }

    func addPortmapping(_ portMapping: PortMapping) {
        if let virtualMachine {
            virtualMachine.portMappings?.append(portMapping)
            reloadPortMappings()
        }
    }

    @IBAction func deletePortmapping(_ sender: Any) {
        if let virtualMachine {
            let row = mappingsTableView.row(for: sender as! NSView)
            virtualMachine.portMappings?.remove(at: row)
            reloadPortMappings()
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        let destinationController = segue.destinationController as! NewPortMappingViewController
        destinationController.setParentController(self)
        if let virtualMachine {
            if let portMappings = virtualMachine.portMappings {
                if segue.identifier == MacMulatorConstants.NEW_PORT_MAPPING_SEGUE {
                    destinationController.setMode(NewPortMappingViewController.Mode.ADD)
                }
                if segue.identifier == MacMulatorConstants.EDIT_PORT_MAPPING_SEGUE {
                    destinationController.setMode(NewPortMappingViewController.Mode.EDIT)
                    let driveTableRow: Int = mappingsTableView.row(for: sender as! NSView)
                    destinationController.setPortmapping(portMappings[driveTableRow])
                }
            }
        }
    }

    func numberOfRows(in _: NSTableView) -> Int {
        virtualMachine?.portMappings?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self)

        if let virtualMachine {
            if let portMappings = virtualMachine.portMappings {
                let mapping = portMappings[row]

                if tableColumn?.identifier.rawValue == "Name" {
                    let cellView = cell as! MappingsNameCell
                    cellView.label.stringValue = mapping.name
                }

                if tableColumn?.identifier.rawValue == "VM" {
                    let cellView = cell as! VirtualMachinePortCell
                    cellView.label.intValue = mapping.vmPort
                }

                if tableColumn?.identifier.rawValue == "Host" {
                    let cellView = cell as! HostMacPortCell
                    cellView.label.intValue = mapping.hostPort
                }
            }
        }

        return cell
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        30.0
    }

    func numberOfItems(in _: NSComboBox) -> Int {
        QemuConstants.ALL_NETWORK_ADAPTERS_DESC.count
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if comboBox == networkAdapterComboBox {
            return index >= 0 ? QemuConstants.ALL_NETWORK_ADAPTERS_DESC[QemuConstants.ALL_NETWORK_ADAPTERS[index]] : ""
        }
        return index + 1
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        if (notification.object as! NSComboBox) == networkAdapterComboBox {
            if let virtualMachine {
                virtualMachine.networkDevice = QemuConstants.ALL_NETWORK_ADAPTERS[networkAdapterComboBox.indexOfSelectedItem]
            }
        }
    }
}
