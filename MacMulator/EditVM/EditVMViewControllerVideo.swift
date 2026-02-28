
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
    @IBOutlet var qemuDisplayLabel: NSTextField!
    @IBOutlet var qemuDisplayComboBox: NSComboBox!
    @IBOutlet var accelDescriptiontext: NSTextField!
    @IBOutlet var accelDescriptionLabel: NSTextField!
    @IBOutlet var accelDescriptionSwitch: NSSwitch!
    @IBOutlet var windowsArmDescriptionText: NSTextField!

    var virtualMachine: VirtualMachine?

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        updateView()
    }

    override func viewWillAppear() {
        videoDescriptionText.stringValue = NSLocalizedString("EditVMViewControllerVideo.videoDescriptionText", comment: "")
        videoAdapterLabel.stringValue = NSLocalizedString("EditVMViewControllerVideo.videoAdapterLabel", comment: "")
        qemuDisplayLabel.stringValue = NSLocalizedString("EditVMViewControllerVideo.qemuDisplayLabel", comment: "")
        accelDescriptiontext.stringValue = NSLocalizedString("EditVMViewControllerVideo.accelDescriptiontext", comment: "")
        accelDescriptionLabel.stringValue = NSLocalizedString("EditVMViewControllerVideo.accelDescriptionLabel", comment: "")
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
            qemuDisplayComboBox.reloadData()
            if virtualMachine.architecture == QemuConstants.ARCH_ARM64, virtualMachine.subtype == QemuConstants.SUB_WINDOWS_11 {
                windowsArmDescriptionText.isHidden = false
            } else {
                windowsArmDescriptionText.isHidden = true
            }
        }
    }

    func numberOfItems(in comboBox: NSComboBox) -> Int {
        if comboBox == videoAdapterComboBox {
            return buildAdaptersList().count
        } else if comboBox == qemuDisplayComboBox {
            return QemuConstants.ALL_DISPLAYS.count
        }
        return 0
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if comboBox == videoAdapterComboBox {
            return index >= 0 ? QemuConstants.ALL_VIDEO_ADAPTERS_DESC[buildAdaptersList()[index]] : ""
        } else if comboBox == qemuDisplayComboBox {
            return index >= 0 ? QemuConstants.ALL_DISPLAYS_DESC[QemuConstants.ALL_DISPLAYS[index]] : ""
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
