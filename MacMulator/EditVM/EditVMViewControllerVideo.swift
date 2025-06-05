
//
//  EditVMViewControllerVideo.swift
//  MacMulator
//
//  Created by Vale on 03/06/22.
//

import Cocoa

class EditVMViewControllerVideo: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate {
    @IBOutlet var videoDescriptionText: NSTextField!
    @IBOutlet var videoAdapterLabel: NSTextField!
    @IBOutlet var videoAdapterComboBox: NSComboBox!
    @IBOutlet var windowsArmDescriptionText: NSTextField!

    var virtualMachine: VirtualMachine?

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        updateView()
    }

    override func viewWillAppear() {
        videoDescriptionText.stringValue = NSLocalizedString("EditVMViewControllerVideo.videoDescriptionText", comment: "")
        videoAdapterLabel.stringValue = NSLocalizedString("EditVMViewControllerVideo.videoAdapterLabel", comment: "")
        windowsArmDescriptionText.stringValue = NSLocalizedString("EditVMViewControllerVideo.windowsArmDescriptionText", comment: "")
        updateView()
    }

    fileprivate func buildAdaptersList() -> [String] {
        var videoAdapters = QemuConstants.ALL_VIDEO_ADAPTERS
        if let virtualMachine {
            if virtualMachine.architecture == QemuConstants.ARCH_X64 {
                videoAdapters.append(contentsOf: QemuConstants.INTEL_ONLY_VIDEO_ADAPTERS)
            }
        }
        return videoAdapters
    }

    func updateView() {
        if let virtualMachine {
            videoAdapterComboBox.reloadData()
            videoAdapterComboBox.selectItem(at: buildAdaptersList().firstIndex(of: virtualMachine.videoDevice ?? Utils.getVideoForSubType(virtualMachine.os, virtualMachine.subtype)) ?? -1)
        }
    }

    func numberOfItems(in _: NSComboBox) -> Int {
        buildAdaptersList().count
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if comboBox == videoAdapterComboBox {
            return index >= 0 ? QemuConstants.ALL_VIDEO_ADAPTERS_DESC[buildAdaptersList()[index]] : ""
        }
        return index + 1
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        if (notification.object as! NSComboBox) == videoAdapterComboBox {
            if let virtualMachine {
                virtualMachine.videoDevice = buildAdaptersList()[videoAdapterComboBox.indexOfSelectedItem]
            }
        }
    }
}
