
//
//  EditVMViewControllerNetworkVF.swift
//  MacMulator
//
//  Created by Vale on 03/06/22.
//

import Cocoa
import Virtualization

class EditVMViewControllerNetworkVF: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate {
    @IBOutlet var networkAdapterLabel: NSTextField!
    @IBOutlet var networkAdapterComboBox: NSComboBox!
    @IBOutlet var phisicalDeviceComboBox: NSComboBox!
    @IBOutlet var physicalDeviceLabel: NSTextField!
    @IBOutlet var descriptionText: NSTextField!

    var virtualMachine: VirtualMachine?

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        updateView()
    }

    override func viewWillAppear() {
//        networkAdapterLabel.stringValue = NSLocalizedString("EditVMViewControllerNetwork.networkAdapterLabel", comment: "")

        updateView()
    }

    fileprivate func updateSecondaryBox(attachment: String) {
        if attachment == QemuConstants.ATTACHMENT_BRIDGED {
            phisicalDeviceComboBox.isEnabled = true
        } else {
            phisicalDeviceComboBox.isEnabled = false
            phisicalDeviceComboBox.deselectItem(at: phisicalDeviceComboBox.indexOfSelectedItem)
        }
    }

    func updateView() {
        if let virtualMachine {
            networkAdapterComboBox.reloadData()
            networkAdapterComboBox.selectItem(at: QemuConstants.APPLE_NETWORK_ATTACHMENTS.firstIndex(of: virtualMachine.networkDevice ?? QemuConstants.ATTACHMENT_NAT) ?? 0)

            updateSecondaryBox(attachment: virtualMachine.networkDevice ?? QemuConstants.ATTACHMENT_NAT)
        }
    }

    func numberOfItems(in comboBox: NSComboBox) -> Int {
        if comboBox == networkAdapterComboBox {
            QemuConstants.APPLE_NETWORK_ATTACHMENTS.count
        } else {
            VZBridgedNetworkInterface.networkInterfaces.count
        }
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if comboBox == networkAdapterComboBox {
            index >= 0 ? QemuConstants.APPLE_NETWORK_ATTACHMENTS_DESC[QemuConstants.APPLE_NETWORK_ATTACHMENTS[index]] : ""
        } else {
            VZBridgedNetworkInterface.networkInterfaces[index].localizedDisplayName
        }
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        if (notification.object as! NSComboBox) == networkAdapterComboBox {
            if let virtualMachine {
                virtualMachine.networkDevice = QemuConstants.APPLE_NETWORK_ATTACHMENTS[networkAdapterComboBox.indexOfSelectedItem]
                updateSecondaryBox(attachment: QemuConstants.APPLE_NETWORK_ATTACHMENTS[networkAdapterComboBox.indexOfSelectedItem])
            }
        } else {}
    }
}
