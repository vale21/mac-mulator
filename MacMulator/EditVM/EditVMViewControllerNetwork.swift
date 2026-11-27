//
//  EditVMViewControllerNetwork.swift
//  MacMulator
//
//  Created by Vale on 03/06/22.
//

import Cocoa
import Virtualization

class EditVMViewControllerNetwork: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTableViewDataSource, NSTableViewDelegate, PortMappingsEditor, VmnetNetworkSelector {
    @IBOutlet var networkModeLabel: NSTextField!
    @IBOutlet var networkModeComboBox: NSComboBox!
    @IBOutlet var physicalDeviceLabel: NSTextField!
    @IBOutlet var physicalDeviceComboBox: NSComboBox!
    @IBOutlet var manageNetworksButton: NSButton!
    @IBOutlet var networkAdapterLabel: NSTextField!
    @IBOutlet var networkAdapterComboBox: NSComboBox!
    @IBOutlet var descriptionText: NSTextField!
    @IBOutlet var portMappingsLabel: NSTextField!
    @IBOutlet var portMappingsDescription: NSTextField!
    @IBOutlet var portMappingsScrollView: NSScrollView!
    @IBOutlet var mappingsTableView: NSTableView!
    @IBOutlet var createMappingButton: NSButton!
    @IBOutlet var networkingLabel: NSTextField!
    @IBOutlet var networkingSwitch: NSSwitch!
    @IBOutlet var networkingBox: NSBox!

    var virtualMachine: VirtualMachine?
    var adaptersList: [String] = []
    var networkModes: [String] = [QemuConstants.NETWORK_MODE_USER]
    var vmnetNetworks: [VmnetNetwork] = []

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm

        loadNetworkModes()
        loadAdaptersList()
        updateView()
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
        networkModeLabel.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.networkMode", comment: "")
        networkAdapterLabel.stringValue = NSLocalizedString("EditVMViewControllerNetwork.networkAdapterLabel", comment: "")
        manageNetworksButton.title = NSLocalizedString("EditVMViewControllerNetworkVF.manageNetworksButton", comment: "")
        portMappingsLabel.stringValue = NSLocalizedString("EditVMViewControllerNetwork.portMappingsLabel", comment: "")
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
                    cellView.label.stringValue = String(mapping.vmPort)
                }

                if tableColumn?.identifier.rawValue == "Host" {
                    let cellView = cell as! HostMacPortCell
                    cellView.label.stringValue = String(mapping.hostPort)
                }
            }
        }

        return cell
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        30.0
    }

    func numberOfItems(in comboBox: NSComboBox) -> Int {
        if comboBox == networkAdapterComboBox {
            adaptersList.count
        } else if comboBox == networkModeComboBox {
            networkModes.count
        } else if selectedNetworkMode() == QemuConstants.NETWORK_MODE_VMNET {
            vmnetNetworks.count
        } else if selectedNetworkMode() == QemuConstants.NETWORK_MODE_BRIDGED {
            VZBridgedNetworkInterface.networkInterfaces.count
        } else {
            0
        }
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if comboBox == networkAdapterComboBox {
            index >= 0 ? QemuConstants.ALL_NETWORK_ADAPTERS_DESC[adaptersList[index]] : ""
        } else if comboBox == networkModeComboBox {
            index >= 0 ? QemuConstants.QEMU_NETWORK_MODES_DESC[networkModes[index]] : ""
        } else if selectedNetworkMode() == QemuConstants.NETWORK_MODE_VMNET {
            vmnetNetworks[index].name
        } else {
            VZBridgedNetworkInterface.networkInterfaces[index].localizedDisplayName
        }
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let virtualMachine, let comboBox = notification.object as? NSComboBox else { return }

        if comboBox == networkAdapterComboBox {
            virtualMachine.networkDevice = adaptersList[networkAdapterComboBox.indexOfSelectedItem]
        } else if comboBox == networkModeComboBox {
            virtualMachine.networkMode = networkModes[networkModeComboBox.indexOfSelectedItem]
            updateNetworkModeControls()
        } else if comboBox == physicalDeviceComboBox {
            let index = physicalDeviceComboBox.indexOfSelectedItem
            guard index >= 0 else { return }

            if selectedNetworkMode() == QemuConstants.NETWORK_MODE_VMNET {
                virtualMachine.vmnetNetworkId = vmnetNetworks[index].id
                updateVmnetDescriptionAndPortMappings()
            } else {
                virtualMachine.physicalBridgeNetworkDevice = VZBridgedNetworkInterface.networkInterfaces[index].identifier
            }
        }
    }

    func updateView() {
        if let virtualMachine {
            networkModeComboBox.reloadData()
            networkModeComboBox.selectItem(at: networkModes.firstIndex(of: selectedNetworkMode()) ?? 0)

            networkAdapterComboBox.reloadData()
            networkAdapterComboBox.selectItem(at: adaptersList.firstIndex(of: virtualMachine.networkDevice ?? Utils.getNetworkForSubType(virtualMachine.os, virtualMachine.subtype, MacMulatorConstants.QEMU_VM)) ?? -1)

            updateNetworkingControls()
        }
    }

    func reloadPortMappings() {
        mappingsTableView.reloadData()
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

    func selectVmnetNetwork(_ network: VmnetNetwork) {
        virtualMachine?.vmnetNetworkId = network.id
        updateNetworkModeControls()
    }

    @objc private func vmnetNetworksDidChange(_: Notification) {
        updateNetworkModeControls()
    }

    private func updateNetworkingControls() {
        let enabled = virtualMachine?.isNetworkEnabled ?? true
        networkingSwitch.state = enabled ? .on : .off
        Utils.setControlsEnabled(enabled, in: networkingBox)
        // Enabling everything also enables controls that depend on the network mode, like the device list in user mode
        updateNetworkModeControls()
    }

    private func loadNetworkModes() {
        guard let virtualMachine else { return }

        networkModes = [QemuConstants.NETWORK_MODE_USER]
        guard Utils.isQemuForwardedNetworkSupported(virtualMachine) else { return }

        networkModes.append(QemuConstants.NETWORK_MODE_BRIDGED)
        if Utils.isVmnetSupported(virtualMachine) {
            networkModes.append(QemuConstants.NETWORK_MODE_VMNET)
        }
    }

    private func loadAdaptersList() {
        guard let virtualMachine else { return }

        adaptersList = QemuCapabilitiesReporter.getInstance(forQemuPath: QemuUtils.getQemuPath(for: virtualMachine))?.availableNetworkDevices ?? QemuConstants.ALL_NETWORK_ADAPTERS
    }

    private func selectedNetworkMode() -> String {
        // Read from the VM, not the combo box: the combo boxes query their data source while the storyboard is still connecting outlets
        if let networkMode = virtualMachine?.networkMode, networkModes.contains(networkMode) {
            return networkMode
        }
        return QemuConstants.NETWORK_MODE_USER
    }

    private func updateNetworkModeControls() {
        guard let virtualMachine else { return }

        let networkMode = selectedNetworkMode()
        let networkingEnabled = virtualMachine.isNetworkEnabled
        manageNetworksButton.isHidden = networkMode != QemuConstants.NETWORK_MODE_VMNET

        if networkMode == QemuConstants.NETWORK_MODE_BRIDGED {
            physicalDeviceLabel.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.phisicalDevice", comment: "")
            physicalDeviceComboBox.isEnabled = networkingEnabled
            physicalDeviceComboBox.reloadData()
            if let device = virtualMachine.physicalBridgeNetworkDevice, let index = VZBridgedNetworkInterface.networkInterfaces.firstIndex(where: { $0.identifier == device }) {
                physicalDeviceComboBox.selectItem(at: index)
            } else {
                physicalDeviceComboBox.selectItem(at: 0)
            }
            descriptionText.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.descriptionBridged", comment: "")
            setPortMappingsVisible(false)
        } else if networkMode == QemuConstants.NETWORK_MODE_VMNET {
            physicalDeviceLabel.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.vmnetNetwork", comment: "")
            physicalDeviceComboBox.isEnabled = networkingEnabled
            vmnetNetworks = VmnetNetwork.allNetworks()
            physicalDeviceComboBox.reloadData()

            if VmnetNetwork.network(withId: virtualMachine.vmnetNetworkId) == nil {
                virtualMachine.vmnetNetworkId = VmnetNetwork.SHARED_ID
            }
            physicalDeviceComboBox.selectItem(at: vmnetNetworks.firstIndex { $0.id == virtualMachine.vmnetNetworkId } ?? 0)
            updateVmnetDescriptionAndPortMappings()
        } else {
            physicalDeviceLabel.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.phisicalDevice", comment: "")
            physicalDeviceComboBox.isEnabled = false
            physicalDeviceComboBox.reloadData()
            physicalDeviceComboBox.stringValue = ""
            descriptionText.stringValue = NSLocalizedString("EditVMViewControllerNetwork.descriptionUser", comment: "")
            portMappingsDescription.stringValue = NSLocalizedString("EditVMViewControllerNetwork.portMappingsDescription", comment: "")
            setPortMappingsVisible(true)
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
        portMappingsDescription.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.portMappingsDescription", comment: "")
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
