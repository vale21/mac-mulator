//
//  EditVmnetNetworkViewController.swift
//  MacMulator
//
//  Created by Vale on 18/11/26.
//

import Cocoa

class EditVmnetNetworkViewController: NSViewController, NSComboBoxDelegate {
    enum Mode {
        case ADD
        case EDIT
    }

    @IBOutlet var titleField: NSTextField!
    @IBOutlet var nameLabel: NSTextField!
    @IBOutlet var nameField: NSTextField!
    @IBOutlet var modeLabel: NSTextField!
    @IBOutlet var modeComboBox: NSComboBox!
    @IBOutlet var subnetLabel: NSTextField!
    @IBOutlet var subnetField: NSTextField!
    @IBOutlet var dhcpCheckbox: NSButton!
    @IBOutlet var natCheckbox: NSButton!
    @IBOutlet var modeDescription: NSTextField!

    static let MODES: [VmnetNetwork.Mode] = [.shared, .hostOnly]

    var parentController: ManageVmnetNetworksViewController?
    var network: VmnetNetwork?
    var mode: Mode = .ADD

    func setParentController(_ parentController: ManageVmnetNetworksViewController) {
        self.parentController = parentController
    }

    func setNetwork(_ network: VmnetNetwork) {
        self.network = network
    }

    func setMode(_ mode: Mode) {
        self.mode = mode
    }

    @IBAction func okButtonPressed(_: Any) {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            showError(NSLocalizedString("EditVmnetNetworkViewController.nameMissing", comment: ""))
            return
        }
        if parentController?.isNameInUse(name, excluding: network) == true {
            showError(String(format: NSLocalizedString("EditVmnetNetworkViewController.nameInUse", comment: ""), name))
            return
        }
        let subnet = subnetField.stringValue.trimmingCharacters(in: .whitespaces)
        if !VmnetNetwork.isValidSubnet(subnet) {
            showError(String(format: NSLocalizedString("EditVmnetNetworkViewController.invalidSubnet", comment: ""), subnet))
            return
        }
        if let other = parentController?.overlappingNetwork(with: subnet, excluding: network) {
            showError(String(format: NSLocalizedString("EditVmnetNetworkViewController.subnetOverlaps", comment: ""), subnet, other.name, other.addressRange))
            return
        }

        let selectedMode = EditVmnetNetworkViewController.MODES[max(modeComboBox.indexOfSelectedItem, 0)]
        let natEnabled = selectedMode == .shared && natCheckbox.state == .on
        if mode == Mode.ADD {
            parentController?.addNetwork(VmnetNetwork(name: name, mode: selectedMode, subnet: subnet, dhcpEnabled: dhcpCheckbox.state == .on, natEnabled: natEnabled))
        } else if let network {
            network.name = name
            network.mode = selectedMode
            network.subnet = subnet
            network.dhcpEnabled = dhcpCheckbox.state == .on
            network.natEnabled = natEnabled
            parentController?.networkUpdated()
        }
        dismiss(self)
    }

    @IBAction func cancelButtonPressed(_: Any) {
        dismiss(self)
    }

    override func viewWillAppear() {
        nameLabel.stringValue = NSLocalizedString("EditVmnetNetworkViewController.nameLabel", comment: "")
        modeLabel.stringValue = NSLocalizedString("EditVmnetNetworkViewController.modeLabel", comment: "")
        subnetLabel.stringValue = NSLocalizedString("EditVmnetNetworkViewController.subnetLabel", comment: "")
        dhcpCheckbox.title = NSLocalizedString("EditVmnetNetworkViewController.dhcp", comment: "")
        natCheckbox.title = NSLocalizedString("EditVmnetNetworkViewController.nat", comment: "")

        modeComboBox.removeAllItems()
        for networkMode in EditVmnetNetworkViewController.MODES {
            modeComboBox.addItem(withObjectValue: networkMode.localizedName)
        }

        updateView()
    }

    func comboBoxSelectionDidChange(_: Notification) {
        updateNatCheckbox()
    }

    private func updateView() {
        if mode == Mode.ADD {
            titleField.stringValue = NSLocalizedString("EditVmnetNetworkViewController.createNetwork", comment: "")
            nameField.stringValue = ""
            modeComboBox.selectItem(at: 0)
            subnetField.stringValue = "192.168.130.0/24"
            dhcpCheckbox.state = .on
            natCheckbox.state = .on
        } else if let network {
            titleField.stringValue = String(format: NSLocalizedString("EditVmnetNetworkViewController.editNetwork", comment: ""), network.name)
            nameField.stringValue = network.name
            modeComboBox.selectItem(at: EditVmnetNetworkViewController.MODES.firstIndex(of: network.mode) ?? 0)
            subnetField.stringValue = network.subnet
            dhcpCheckbox.state = network.dhcpEnabled ? .on : .off
            natCheckbox.state = network.natEnabled ? .on : .off
        }
        updateNatCheckbox()
    }

    /// NAT only makes sense on shared networks: host-only networks never reach outside the host Mac.
    private func updateNatCheckbox() {
        let isShared = EditVmnetNetworkViewController.MODES[max(modeComboBox.indexOfSelectedItem, 0)] == .shared
        natCheckbox.isEnabled = isShared
        if !isShared {
            natCheckbox.state = .off
        }
        modeDescription.stringValue = NSLocalizedString(isShared ? "EditVmnetNetworkViewController.sharedDescription" : "EditVmnetNetworkViewController.hostOnlyDescription", comment: "")
    }

    private func showError(_ message: String) {
        Utils.showAlert(window: view.window!, style: NSAlert.Style.warning, message: message, virtualMachine: nil)
    }
}
