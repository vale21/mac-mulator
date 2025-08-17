
//
//  EditVMViewControllerNetworkVF.swift
//  MacMulator
//
//  Created by Vale on 03/06/22.
//

import Cocoa

class EditVMViewControllerNetworkVF: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet var networkAdapterLabel: NSTextField!
    @IBOutlet var networkAdapterComboBox: NSComboBox!

    var virtualMachine: VirtualMachine?

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        updateView()
    }

    override func viewWillAppear() {
//        networkAdapterLabel.stringValue = NSLocalizedString("EditVMViewControllerNetwork.networkAdapterLabel", comment: "")

        updateView()
    }

    func updateView() {
        if let virtualMachine {
            networkAdapterComboBox.reloadData()
            networkAdapterComboBox.selectItem(at: QemuConstants.ALL_NETWORK_ADAPTERS.firstIndex(of: virtualMachine.networkDevice ?? Utils.getNetworkForSubType(virtualMachine.os, virtualMachine.subtype)) ?? -1)
        }
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
