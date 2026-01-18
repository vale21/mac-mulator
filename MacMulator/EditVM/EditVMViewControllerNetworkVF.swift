
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
        updateView()
    }

    fileprivate func updateSecondaryBoxAndDescription(attachment: String) {
        if let virtualMachine {
            if attachment == QemuConstants.ATTACHMENT_BRIDGED {
                phisicalDeviceComboBox.isEnabled = true
                if let device = virtualMachine.physicalBridgeNetworkDevice, let idx = VZBridgedNetworkInterface.networkInterfaces.firstIndex(where: { $0.identifier == device }) {
                    phisicalDeviceComboBox.selectItem(at: idx)
                } else {
                    phisicalDeviceComboBox.selectItem(at: 0)
                }
                descriptionText.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.descriptionBridged", comment: "")
            } else {
                phisicalDeviceComboBox.isEnabled = false
                descriptionText.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.descriptionNat", comment: "")
            }
        }
    }

    func updateView() {
        if let virtualMachine {
            networkAdapterComboBox.reloadData()
            networkAdapterComboBox.selectItem(at: QemuConstants.APPLE_NETWORK_ATTACHMENTS.firstIndex(of: virtualMachine.networkDevice ?? QemuConstants.ATTACHMENT_NAT) ?? 0)

            updateSecondaryBoxAndDescription(attachment: virtualMachine.networkDevice ?? QemuConstants.ATTACHMENT_NAT)

            networkAdapterLabel.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.networkMode", comment: "")
            physicalDeviceLabel.stringValue = NSLocalizedString("EditVMViewControllerNetworkVF.phisicalDevice", comment: "")
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
        if let virtualMachine {
            if (notification.object as! NSComboBox) == networkAdapterComboBox {
                virtualMachine.networkDevice = QemuConstants.APPLE_NETWORK_ATTACHMENTS[networkAdapterComboBox.indexOfSelectedItem]
                updateSecondaryBoxAndDescription(attachment: QemuConstants.APPLE_NETWORK_ATTACHMENTS[networkAdapterComboBox.indexOfSelectedItem])
            } else if (notification.object as! NSComboBox) == phisicalDeviceComboBox {
                virtualMachine.physicalBridgeNetworkDevice = VZBridgedNetworkInterface.networkInterfaces[phisicalDeviceComboBox.indexOfSelectedItem].identifier
            }
        }
    }
}
