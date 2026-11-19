//
//  ManageVmnetNetworksViewController.swift
//  MacMulator
//
//  Created by Vale on 18/11/26.
//

import Cocoa

class VmnetNetworksButtonsCell: NSTableCellView {
    @IBOutlet var editButton: NSButton!
    @IBOutlet var deleteButton: NSButton!
}

class ManageVmnetNetworksViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet var titleField: NSTextField!
    @IBOutlet var descriptionField: NSTextField!
    @IBOutlet var networksTableView: NSTableView!
    @IBOutlet var addButton: NSButton!
    @IBOutlet var doneButton: NSButton!

    var parentController: EditVMViewControllerNetworkVF?
    var networks: [VmnetNetwork] = []
    var networkToEdit: VmnetNetwork?

    func setParentController(_ parentController: EditVMViewControllerNetworkVF) {
        self.parentController = parentController
    }

    @IBAction func addButtonPressed(_: Any) {
        performSegue(withIdentifier: MacMulatorConstants.NEW_VMNET_NETWORK_SEGUE, sender: self)
    }

    @IBAction func editNetwork(_ sender: Any) {
        edit(row: networksTableView.row(for: sender as! NSView))
    }

    @IBAction func deleteNetwork(_ sender: Any) {
        guard let network = network(at: networksTableView.row(for: sender as! NSView)), !network.isBuiltIn else { return }

        Utils.showPrompt(window: view.window!, style: NSAlert.Style.informational, message: String(format: NSLocalizedString("ManageVmnetNetworksViewController.confirmRemove", comment: ""), network.name), completionHandler: { response in
            if response.rawValue == Utils.ALERT_RESP_OK {
                self.networks.removeAll { $0.id == network.id }
                self.networksChanged()
            }
        }, virtualMachine: nil)
    }

    @IBAction func doneButtonPressed(_: Any) {
        dismiss(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        networksTableView.target = self
        networksTableView.doubleAction = #selector(tableViewDoubleClicked(_:))
    }

    override func viewWillAppear() {
        titleField.stringValue = NSLocalizedString("ManageVmnetNetworksViewController.title", comment: "")
        descriptionField.stringValue = NSLocalizedString("ManageVmnetNetworksViewController.description", comment: "")
        addButton.title = NSLocalizedString("ManageVmnetNetworksViewController.add", comment: "")
        doneButton.title = NSLocalizedString("ManageVmnetNetworksViewController.done", comment: "")

        for column in networksTableView.tableColumns where column.identifier.rawValue != "Buttons" {
            column.headerCell.title = NSLocalizedString("ManageVmnetNetworksViewController.column" + column.identifier.rawValue, comment: "")
        }

        networks = VmnetNetwork.allNetworks()
        networksTableView.reloadData()
    }

    override func prepare(for segue: NSStoryboardSegue, sender _: Any?) {
        let destinationController = segue.destinationController as! EditVmnetNetworkViewController
        destinationController.setParentController(self)
        if segue.identifier == MacMulatorConstants.NEW_VMNET_NETWORK_SEGUE {
            destinationController.setMode(EditVmnetNetworkViewController.Mode.ADD)
        } else if segue.identifier == MacMulatorConstants.EDIT_VMNET_NETWORK_SEGUE, let network = networkToEdit {
            destinationController.setMode(EditVmnetNetworkViewController.Mode.EDIT)
            destinationController.setNetwork(network)
        }
    }

    func numberOfRows(in _: NSTableView) -> Int {
        networks.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView else {
            return nil
        }

        let network = networks[row]
        if let buttonsCell = cell as? VmnetNetworksButtonsCell {
            // Built-in networks cannot be modified
            buttonsCell.editButton.isEnabled = !network.isBuiltIn
            buttonsCell.deleteButton.isEnabled = !network.isBuiltIn
            return buttonsCell
        }

        switch tableColumn.identifier.rawValue {
        case "Name":
            cell.textField?.stringValue = network.isBuiltIn ? String(format: NSLocalizedString("ManageVmnetNetworksViewController.builtIn", comment: ""), network.name) : network.name
        case "Mode":
            cell.textField?.stringValue = network.mode.localizedName
        case "Subnet":
            cell.textField?.stringValue = network.mode == .isolated ? String(format: NSLocalizedString("ManageVmnetNetworksViewController.automaticSubnet", comment: ""), network.addressRange) : network.subnet
        case "DHCP":
            cell.textField?.stringValue = onOffString(network.dhcpEnabled)
        case "NAT":
            cell.textField?.stringValue = network.mode == .shared ? onOffString(network.natEnabled) : "-"
        default:
            break
        }
        // Built-in networks cannot be modified: show them dimmed.
        cell.textField?.textColor = network.isBuiltIn ? .secondaryLabelColor : .labelColor
        return cell
    }

    func isNameInUse(_ name: String, excluding network: VmnetNetwork?) -> Bool {
        networks.contains { $0 !== network && $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// The first network, other than the given one, whose address range overlaps the subnet
    func overlappingNetwork(with subnet: String, excluding network: VmnetNetwork?) -> VmnetNetwork? {
        networks.first { $0 !== network && VmnetNetwork.subnetsOverlap(subnet, $0.addressRange) }
    }

    func addNetwork(_ network: VmnetNetwork) {
        networks.append(network)
        networksChanged()
        networksTableView.selectRowIndexes(IndexSet(integer: networks.count - 1), byExtendingSelection: false)
    }

    func networkUpdated() {
        networksChanged()
    }

    private func networksChanged() {
        VmnetNetwork.saveUserNetworks(networks)
        networksTableView.reloadData()
        parentController?.vmnetNetworksChanged()
    }

    @objc private func tableViewDoubleClicked(_: Any) {
        edit(row: networksTableView.clickedRow)
    }

    private func edit(row: Int) {
        guard let network = network(at: row), !network.isBuiltIn else { return }

        networkToEdit = network
        performSegue(withIdentifier: MacMulatorConstants.EDIT_VMNET_NETWORK_SEGUE, sender: self)
    }

    private func network(at row: Int) -> VmnetNetwork? {
        row >= 0 && row < networks.count ? networks[row] : nil
    }

    private func onOffString(_ value: Bool) -> String {
        NSLocalizedString(value ? "ManageVmnetNetworksViewController.on" : "ManageVmnetNetworksViewController.off", comment: "")
    }
}
