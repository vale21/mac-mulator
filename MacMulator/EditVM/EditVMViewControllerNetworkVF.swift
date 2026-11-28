//
//  EditVMViewControllerNetworkVF.swift
//  MacMulator
//
//  Created by Vale on 03/06/22.
//

import Cocoa
import Virtualization

class EditVMViewControllerNetworkVF: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTableViewDataSource, NSTableViewDelegate, PortMappingsEditor, VmnetNetworkSelector, VMSettingsLockable {
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
    @IBOutlet var networkingLabel: NSTextField!
    @IBOutlet var networkingSwitch: NSSwitch!
    @IBOutlet var networkingBox: NSBox!

    var virtualMachine: VirtualMachine?
    var attachments: [String] = QemuConstants.APPLE_NETWORK_ATTACHMENTS
    var vmnetNetworks: [VmnetNetwork] = []
    var vmLocked = false

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        if virtualMachine?.type == MacMulatorConstants.APPLE_VM || virtualMachine?.type == MacMulatorConstants.APPLE_TEMPLATE_VM {
            loadAttachments()
            updateView()
        }
    }

    func setVMLocked(_ locked: Bool) {
        vmLocked = locked
        if isViewLoaded {
            // Locking disables every control: unlocking enables them all before the view gives each one its state again
            Utils.setControlsEnabled(true, in: view)
            updateView()
        }
    }

    @IBAction func openNetworksPreferences(_: Any) {
        (NSApp.delegate as? AppDelegate)?.showPreferences(PreferencesRequest(tabIdentifier: PreferencesTabViewController.NETWORKS_TAB, networkSelectionTarget: self))
    }

    @IBAction func networkingSwitchChanged(_: Any) {
        virtualMachine?.networkEnabled = networkingSwitch.state == .on
        updateNetworkingControls()
    }

    @IBAction func deletePortmapping(_ sender: Any) {
        if let virtualMachine {
            let row = mappingsTableView.row(for: sender as! NSView)
            virtualMachine.portMappings?.remove(at: row)
            reloadPortMappings()
            if let message = Utils.pendingPortMappingChangeMessage(virtualMachine), let window = view.window {
                Utils.showAlert(window: window, style: NSAlert.Style.informational, message: message, virtualMachine: virtualMachine)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(vmnetNetworksDidChange(_:)), name: MacMulatorConstants.VMNET_NETWORKS_CHANGED_NOTIFICATION, object: nil)
    }

    override func viewWillAppear() {
        networkingLabel.stringValue = NSLocalizedString("EditVMViewControllerNetwork.networkingLabel", comment: "")
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
                cellView.label.stringValue = String(mapping.vmPort)
            }

            if tableColumn?.identifier.rawValue == "Host" {
                let cellView = cell as! HostMacPortCell
                cellView.label.stringValue = String(mapping.hostPort)
            }
        }
        if let cell {
            Utils.setControlsEnabled(!vmLocked, in: cell)
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
            updateNetworkingControls()
            if vmLocked {
                Utils.setControlsEnabled(false, in: view)
            }
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

    func vmnetNetworksChanged() {
        updateSecondaryBoxAndDescription(attachment: selectedAttachment())
    }

    func selectVmnetNetwork(_ network: VmnetNetwork) {
        guard !vmLocked else { return }
        virtualMachine?.vmnetNetworkId = network.id
        vmnetNetworksChanged()
    }

    @objc private func vmnetNetworksDidChange(_: Notification) {
        updateView()
    }

    private func updateNetworkingControls() {
        let enabled = virtualMachine?.isNetworkEnabled ?? true
        networkingSwitch.state = enabled ? .on : .off
        Utils.setControlsEnabled(enabled, in: networkingBox)
        if enabled {
            // Enabling everything also enables controls that depend on the network mode, like the device list with NAT
            updateSecondaryBoxAndDescription(attachment: selectedAttachment())
        }
    }

    private func loadAttachments() {
        guard let virtualMachine else { return }

        attachments = QemuConstants.APPLE_NETWORK_ATTACHMENTS
        if Utils.isVmnetSupported(virtualMachine) {
            attachments.append(QemuConstants.ATTACHMENT_VMNET)
        }
    }

    private func selectedAttachment() -> String {
        // Read from the VM, not the combo box: the combo boxes query their data source while the storyboard is still connecting outlets
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
        } else if network.isVMIsolationEnabled {
            let key = network.mode == .shared && network.natEnabled ? "EditVMViewControllerNetworkVF.descriptionVmnetSharedIsolated" : "EditVMViewControllerNetworkVF.descriptionVmnetHostOnlyIsolated"
            descriptionText.stringValue = NSLocalizedString(key, comment: "")
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
