//
//  EditVMViewControllerNetworkVF.swift
//  MacMulator
//
//  Created by Vale on 03/06/22.
//

import Cocoa
import Virtualization

class EditVMViewControllerNetworkVF: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTableViewDataSource, NSTableViewDelegate, PortMappingsEditor {
    @IBOutlet var networkAdapterLabel: NSTextField!
    @IBOutlet var networkAdapterComboBox: NSComboBox!
    @IBOutlet var phisicalDeviceComboBox: NSComboBox!
    @IBOutlet var physicalDeviceLabel: NSTextField!
    @IBOutlet var descriptionText: NSTextField!
    @IBOutlet var manageNetworksButton: NSButton!
    @IBOutlet var portMappingsLabel: NSTextField!
    @IBOutlet var portMappingsDescription: NSTextField!
    @IBOutlet var portMappingsScrollView: NSScrollView!
    @IBOutlet var mappingsTableView: NSTableView!
    @IBOutlet var createMappingButton: NSButton!

    var virtualMachine: VirtualMachine?
    var attachments: [String] = QemuConstants.APPLE_NETWORK_ATTACHMENTS
    var vmnetNetworks: [VmnetNetwork] = []

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        if virtualMachine?.type == MacMulatorConstants.APPLE_VM || virtualMachine?.type == MacMulatorConstants.APPLE_TEMPLATE_VM {
            loadAttachments()
            updateView()
        }
    }

    @IBAction func deletePortmapping(_ sender: Any) {
        if let virtualMachine {
            let row = mappingsTableView.row(for: sender as! NSView)
            virtualMachine.portMappings?.remove(at: row)
            reloadPortMappings()
        }
    }

    override func viewWillAppear() {
        portMappingsLabel.stringValue = NSLocalizedString("EditVMViewControllerNetwork.portMappingsLabel", comment: "")
        portMappingsDescription.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.portMappingsDescription", comment: "")
        createMappingButton.title = NSLocalizedString("EditVMViewControllerNetwork.createMappingButton", comment: "")
        manageNetworksButton.title = NSLocalizedString("EditVMViewControllerNetworkVF.manageNetworksButton", comment: "")

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

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == MacMulatorConstants.MANAGE_VMNET_NETWORKS_SEGUE {
            let destinationController = segue.destinationController as! ManageVmnetNetworksViewController
            destinationController.setParentController(self)
            return
        }

        let destinationController = segue.destinationController as! NewPortMappingViewController
        destinationController.setParentController(self)
        if let portMappings = virtualMachine?.portMappings {
            if segue.identifier == MacMulatorConstants.NEW_PORT_MAPPING_SEGUE {
                destinationController.setMode(NewPortMappingViewController.Mode.ADD)
            }
            if segue.identifier == MacMulatorConstants.EDIT_PORT_MAPPING_SEGUE {
                destinationController.setMode(NewPortMappingViewController.Mode.EDIT)
                let row = mappingsTableView.row(for: sender as! NSView)
                destinationController.setPortmapping(portMappings[row])
            }
        }
    }

    func numberOfItems(in comboBox: NSComboBox) -> Int {
        if comboBox == networkAdapterComboBox {
            attachments.count
        } else if selectedAttachment() == QemuConstants.ATTACHMENT_VMNET {
            vmnetNetworks.count
        } else if selectedAttachment() == QemuConstants.ATTACHMENT_BRIDGED {
            VZBridgedNetworkInterface.networkInterfaces.count
        } else {
            // NAT has no physical device or network to pick
            0
        }
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if comboBox == networkAdapterComboBox {
            index >= 0 ? QemuConstants.APPLE_NETWORK_ATTACHMENTS_DESC[attachments[index]] : ""
        } else if selectedAttachment() == QemuConstants.ATTACHMENT_VMNET {
            vmnetNetworks[index].name
        } else {
            VZBridgedNetworkInterface.networkInterfaces[index].localizedDisplayName
        }
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        if let virtualMachine {
            if (notification.object as! NSComboBox) == networkAdapterComboBox {
                virtualMachine.networkDevice = attachments[networkAdapterComboBox.indexOfSelectedItem]
                updateSecondaryBoxAndDescription(attachment: attachments[networkAdapterComboBox.indexOfSelectedItem])
            } else if (notification.object as! NSComboBox) == phisicalDeviceComboBox {
                let index = phisicalDeviceComboBox.indexOfSelectedItem
                guard index >= 0 else { return }

                if selectedAttachment() == QemuConstants.ATTACHMENT_VMNET {
                    virtualMachine.vmnetNetworkId = vmnetNetworks[index].id
                    updateVmnetDescriptionAndPortMappings()
                } else {
                    virtualMachine.physicalBridgeNetworkDevice = VZBridgedNetworkInterface.networkInterfaces[index].identifier
                }
            }
        }
    }

    func numberOfRows(in _: NSTableView) -> Int {
        virtualMachine?.portMappings?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self)

        if let mapping = virtualMachine?.portMappings?[row] {
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

        return cell
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        30.0
    }

    func updateView() {
        if let virtualMachine {
            networkAdapterComboBox.reloadData()
            networkAdapterComboBox.selectItem(at: attachments.firstIndex(of: virtualMachine.networkDevice ?? QemuConstants.ATTACHMENT_NAT) ?? 0)

            updateSecondaryBoxAndDescription(attachment: selectedAttachment())

            networkAdapterLabel.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.networkMode", comment: "")
        }
    }

    func addPortmapping(_ portMapping: PortMapping) {
        if let virtualMachine {
            if virtualMachine.portMappings == nil {
                virtualMachine.portMappings = []
            }
            virtualMachine.portMappings?.append(portMapping)
            reloadPortMappings()
        }
    }

    func reloadPortMappings() {
        mappingsTableView.reloadData()
    }

    /// Called by the Manage Networks sheet when the user adds, edits or removes a network.
    func vmnetNetworksChanged() {
        updateSecondaryBoxAndDescription(attachment: selectedAttachment())
    }

    private func loadAttachments() {
        guard let virtualMachine else { return }

        attachments = QemuConstants.APPLE_NETWORK_ATTACHMENTS
        if Utils.isVmnetSupported(virtualMachine) {
            attachments.append(QemuConstants.ATTACHMENT_VMNET)
        }
    }

    /// Read from the VM rather than from the combo box: the combo boxes query their data source while
    /// the storyboard is loading, before all the outlets are connected.
    private func selectedAttachment() -> String {
        if let networkDevice = virtualMachine?.networkDevice, attachments.contains(networkDevice) {
            return networkDevice
        }
        return QemuConstants.ATTACHMENT_NAT
    }

    private func updateSecondaryBoxAndDescription(attachment: String) {
        if let virtualMachine {
            manageNetworksButton.isHidden = attachment != QemuConstants.ATTACHMENT_VMNET

            if attachment == QemuConstants.ATTACHMENT_BRIDGED {
                physicalDeviceLabel.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.phisicalDevice", comment: "")
                phisicalDeviceComboBox.isEnabled = true
                phisicalDeviceComboBox.reloadData()
                if let device = virtualMachine.physicalBridgeNetworkDevice, let idx = VZBridgedNetworkInterface.networkInterfaces.firstIndex(where: { $0.identifier == device }) {
                    phisicalDeviceComboBox.selectItem(at: idx)
                } else {
                    phisicalDeviceComboBox.selectItem(at: 0)
                }
                descriptionText.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.descriptionBridged", comment: "")
                setPortMappingsVisible(false)
            } else if attachment == QemuConstants.ATTACHMENT_VMNET {
                physicalDeviceLabel.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.vmnetNetwork", comment: "")
                phisicalDeviceComboBox.isEnabled = true
                vmnetNetworks = VmnetNetwork.allNetworks()
                phisicalDeviceComboBox.reloadData()

                // Networks deleted from the Manage Networks sheet fall back to the built-in shared network.
                if VmnetNetwork.network(withId: virtualMachine.vmnetNetworkId) == nil {
                    virtualMachine.vmnetNetworkId = VmnetNetwork.SHARED_ID
                }
                phisicalDeviceComboBox.selectItem(at: vmnetNetworks.firstIndex { $0.id == virtualMachine.vmnetNetworkId } ?? 0)
                updateVmnetDescriptionAndPortMappings()
            } else {
                physicalDeviceLabel.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.phisicalDevice", comment: "")
                phisicalDeviceComboBox.isEnabled = false
                phisicalDeviceComboBox.reloadData()
                phisicalDeviceComboBox.stringValue = ""
                descriptionText.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.descriptionNat", comment: "")
                setPortMappingsVisible(false)
            }
        }
    }

    private func updateVmnetDescriptionAndPortMappings() {
        guard let network = VmnetNetwork.network(withId: virtualMachine?.vmnetNetworkId) else { return }

        if network.mode == .isolated {
            descriptionText.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.descriptionVmnetIsolated", comment: "")
        } else if network.mode == .hostOnly {
            descriptionText.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.descriptionVmnetHostOnly", comment: "")
        } else if network.natEnabled {
            descriptionText.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.descriptionVmnetShared", comment: "")
        } else {
            descriptionText.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.descriptionVmnetSharedNoNat", comment: "")
        }
        setPortMappingsVisible(network.supportsPortForwarding)
    }

    private func setPortMappingsVisible(_ visible: Bool) {
        portMappingsLabel.isHidden = !visible
        portMappingsDescription.isHidden = !visible
        portMappingsScrollView.isHidden = !visible
        createMappingButton.isHidden = !visible
        if visible {
            mappingsTableView.reloadData()
        }
    }
}
