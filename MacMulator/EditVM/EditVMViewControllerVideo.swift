//
//  EditVMViewControllerVideo.swift
//  MacMulator
//
//  Created by Vale on 03/06/22.
//

import Cocoa

class EditVMViewControllerVideo: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate {
    @IBOutlet var showScreenLabel: NSTextField!
    @IBOutlet var showScreenSwitch: NSSwitch!
    @IBOutlet var videoDescriptionText: NSTextField!
    @IBOutlet var videoAdapterLabel: NSTextField!
    @IBOutlet var videoAdapterComboBox: NSComboBox!
    @IBOutlet var qemuDisplayLabel: NSTextField!
    @IBOutlet var qemuDisplayComboBox: NSComboBox!
    @IBOutlet var accelDescriptionText: NSTextField!
    @IBOutlet var accelDescriptionLabel: NSTextField!
    @IBOutlet var accelDescriptionSwitch: NSSwitch!
    @IBOutlet var spiceDescriptionText: NSTextField!
    @IBOutlet var spiceDescriptionLabel: NSTextField!
    @IBOutlet var spiceDescriptionSwitch: NSSwitch!
    @IBOutlet var windowsArmDescriptionText: NSTextField!

    var virtualMachine: VirtualMachine?
    var accelerationSupported: Bool = true
    var spiceSupported: Bool = true
    var adaptersList: [String] = []
    var displaysList: [String] = []

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm

        // The other video settings are Qemu ones: Apple VMs only get the "Show VM screen" switch
        if vm.type == MacMulatorConstants.APPLE_VM {
            updateView()
            return
        }

        verifyOpenGLSupport()
        verifySpiceSupport()

        loadAdaptersList()
        loadDisplaysList()

        updateView()
    }

    override func viewWillAppear() {
        showScreenLabel.stringValue = NSLocalizedString("EditVMViewControllerVideo.showScreenLabel", comment: "")
        showScreenSwitch.toolTip = NSLocalizedString("EditVMViewControllerVideo.showScreenTooltip", comment: "")
        videoDescriptionText.stringValue = NSLocalizedString("EditVMViewControllerVideo.videoDescriptionText", comment: "")
        videoAdapterLabel.stringValue = NSLocalizedString("EditVMViewControllerVideo.videoAdapterLabel", comment: "")
        qemuDisplayLabel.stringValue = NSLocalizedString("EditVMViewControllerVideo.qemuDisplayLabel", comment: "")
        accelDescriptionText.stringValue = NSLocalizedString("EditVMViewControllerVideo.accelDescriptiontext", comment: "")
        accelDescriptionLabel.stringValue = NSLocalizedString("EditVMViewControllerVideo.accelDescriptionLabel", comment: "")
        spiceDescriptionText.stringValue = NSLocalizedString("EditVMViewControllerVideo.spiceDescriptionText", comment: "")
        spiceDescriptionLabel.stringValue = NSLocalizedString("EditVMViewControllerVideo.spiceDescriptionLabel", comment: "")
        windowsArmDescriptionText.stringValue = NSLocalizedString("EditVMViewControllerVideo.windowsArmDescriptionText", comment: "")

        updateView()
    }

    fileprivate func loadAdaptersList() {
        guard let virtualMachine else { return }

        let adapters = QemuCapabilitiesReporter.getInstance(forQemuPath: QemuUtils.getQemuPath(for: virtualMachine))?.availableVideoDevices ?? QemuConstants.ALL_VIDEO_ADAPTERS
        adaptersList = QemuUtils.removeDuplicateVideoAdapters(adapters)
        updateView()
    }

    fileprivate func loadDisplaysList() {
        guard let virtualMachine else { return }

        var displays = QemuCapabilitiesReporter.getInstance(forQemuPath: QemuUtils.getQemuPath(for: virtualMachine))?.availableDisplays ?? QemuConstants.ALL_DISPLAYS

        displays.insert(QemuConstants.DISPLAY_DEFAULT, at: 0)
        displaysList = displays
        updateView()
    }

    func updateView() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let virtualMachine, virtualMachine.type == MacMulatorConstants.APPLE_VM {
                showScreenSwitch.state = virtualMachine.headless == true ? .off : .on
                for view in qemuVideoViews {
                    view.isHidden = true
                }
            } else if let virtualMachine {
                videoAdapterComboBox.reloadData()
                videoAdapterComboBox.selectItem(at: adaptersList.firstIndex(of: virtualMachine.videoDevice ?? Utils.getVideoForSubType(virtualMachine.os, virtualMachine.subtype)) ?? 0)
                qemuDisplayComboBox.reloadData()
                qemuDisplayComboBox.selectItem(at: displaysList.firstIndex(of: virtualMachine.qemuDisplay ?? Utils.getDisplayForSubType(virtualMachine.os, virtualMachine.subtype)) ?? 0)

                if virtualMachine.os == QemuConstants.OS_MAC {
                    videoAdapterComboBox.isEnabled = false
                    accelDescriptionText.isHidden = true
                    accelDescriptionLabel.stringValue = NSLocalizedString("EditVMViewControllerVideo.enableAppleParavirtualizedGraphics", comment: "")
                } else {
                    videoAdapterComboBox.isEnabled = true
                    accelDescriptionText.isHidden = false
                    accelDescriptionLabel.stringValue = NSLocalizedString("EditVMViewControllerVideo.accelDescriptionLabel", comment: "")
                }

                if virtualMachine.architecture == QemuConstants.ARCH_ARM64, virtualMachine.subtype == QemuConstants.SUB_WINDOWS_11 {
                    windowsArmDescriptionText.isHidden = false
                } else {
                    windowsArmDescriptionText.isHidden = true
                }

                if spiceSupported {
                    spiceDescriptionText.isEnabled = true
                    spiceDescriptionLabel.isEnabled = true
                    spiceDescriptionSwitch.isEnabled = true
                    spiceDescriptionSwitch.toolTip = NSLocalizedString("EditVMViewControllerVideo.spiceAvailabilityTooltipEnabled", comment: "")

                    spiceDescriptionSwitch.state = (virtualMachine.enableSpiceDisplay ?? true) ? .on : .off
                    qemuDisplayComboBox.isEnabled = spiceDescriptionSwitch.state == .off
                    if virtualMachine.enableSpiceDisplay == true {
                        enableSpiceSupport(self)
                    }
                } else {
                    spiceDescriptionText.isEnabled = false
                    spiceDescriptionLabel.isEnabled = false
                    spiceDescriptionSwitch.isEnabled = false
                    spiceDescriptionSwitch.toolTip = NSLocalizedString("EditVMViewControllerVideo.spiceAvailabilityTooltipDisabled", comment: "")

                    spiceDescriptionSwitch.state = .off
                    virtualMachine.enableSpiceDisplay = false
                    qemuDisplayComboBox.isEnabled = true
                }
                #if APPSTORE
                    // The bundled Qemu has no native display: the Spice display is the only option.
                    spiceDescriptionSwitch.state = .on
                    spiceDescriptionSwitch.isEnabled = false
                    spiceDescriptionSwitch.toolTip = NSLocalizedString("EditVMViewControllerVideo.spiceAvailabilityTooltipEnabled", comment: "")
                    qemuDisplayComboBox.isEnabled = false
                    virtualMachine.enableSpiceDisplay = true
                #endif

                let vmArchitecture = Utils.getMachineArchitecture(virtualMachine.architecture)
                if Utils.hostArchitecture() != vmArchitecture || Utils.isRunningInEmulation() || !accelerationSupported {
                    accelDescriptionText.isEnabled = false
                    accelDescriptionLabel.isEnabled = false
                    accelDescriptionSwitch.isEnabled = false
                    accelDescriptionSwitch.toolTip = virtualMachine.os == QemuConstants.OS_MAC ? NSLocalizedString("EditVMViewControllerVideo.appleParavirtualizedGraphicsTooltipDisabled", comment: "") : NSLocalizedString("EditVMViewControllerVideo.accelAvailabilityTooltipDisabled", comment: "")

                    accelDescriptionSwitch.state = .off
                    virtualMachine.enable3DAcceleration = false
                } else {
                    accelDescriptionText.isEnabled = true
                    accelDescriptionLabel.isEnabled = true
                    accelDescriptionSwitch.isEnabled = true
                    accelDescriptionSwitch.toolTip = virtualMachine.os == QemuConstants.OS_MAC ? NSLocalizedString("EditVMViewControllerVideo.appleParavirtualizedGraphicsTooltipEnabled", comment: "") : NSLocalizedString("EditVMViewControllerVideo.accelAvailabilityTooltipEnabled", comment: "")

                    accelDescriptionSwitch.state = (virtualMachine.enable3DAcceleration ?? true) ? .on : .off
                }

                // A headless VM shows no screen: the display settings do not apply to it
                let headless = virtualMachine.headless == true
                showScreenSwitch.state = headless ? .off : .on
                if headless {
                    for control in qemuVideoViews.compactMap({ $0 as? NSControl }) {
                        control.isEnabled = false
                    }
                } else {
                    // The other controls get their state above: these texts are always enabled otherwise
                    for control in [videoDescriptionText, videoAdapterLabel, qemuDisplayLabel, windowsArmDescriptionText] as [NSControl] {
                        control.isEnabled = true
                    }
                }
            }
        }
    }

    /// Every control of the tab but the "Show VM screen" switch and its label
    private var qemuVideoViews: [NSView] {
        [videoDescriptionText, videoAdapterLabel, videoAdapterComboBox, qemuDisplayLabel, qemuDisplayComboBox,
         accelDescriptionText, accelDescriptionLabel, accelDescriptionSwitch,
         spiceDescriptionText, spiceDescriptionLabel, spiceDescriptionSwitch, windowsArmDescriptionText]
    }

    func numberOfItems(in comboBox: NSComboBox) -> Int {
        if comboBox == videoAdapterComboBox {
            return adaptersList.count
        } else if comboBox == qemuDisplayComboBox {
            return displaysList.count
        }
        return 0
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if comboBox == videoAdapterComboBox {
            return index >= 0 ? QemuConstants.ALL_VIDEO_ADAPTERS_DESC[adaptersList[index]] : ""
        } else if comboBox == qemuDisplayComboBox {
            return index >= 0 ? QemuConstants.ALL_DISPLAYS_DESC[displaysList[index]] : ""
        }
        return index + 1
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        if let virtualMachine {
            if (notification.object as! NSComboBox) == videoAdapterComboBox {
                virtualMachine.videoDevice = adaptersList[videoAdapterComboBox.indexOfSelectedItem]
            } else if (notification.object as! NSComboBox) == qemuDisplayComboBox {
                virtualMachine.qemuDisplay = displaysList[qemuDisplayComboBox.indexOfSelectedItem]
            }
        }
    }

    @IBAction func enable3DAccelerationToggleChanged(_: Any) {
        if let virtualMachine {
            virtualMachine.enable3DAcceleration = accelDescriptionSwitch.state == .on
        }
    }

    @IBAction func showScreenToggleChanged(_: Any) {
        if let virtualMachine {
            virtualMachine.headless = showScreenSwitch.state == .off
        }
        updateView()
    }

    @IBAction func enableSpiceSupport(_: Any) {
        if let virtualMachine {
            virtualMachine.enableSpiceDisplay = spiceDescriptionSwitch.state == .on
        }

        if spiceDescriptionSwitch.state == .on {
            qemuDisplayComboBox.isEnabled = false
        } else {
            qemuDisplayComboBox.isEnabled = true
        }
    }

    fileprivate func verifyOpenGLSupport() {
        if let virtualMachine {
            let capabilities = QemuCapabilitiesReporter.getInstance(forQemuPath: QemuUtils.getQemuPath(for: virtualMachine))
            let virGLSupported = capabilities?.virGLSupported ?? false
            let appleParavirtualizedGraphicsSupported = capabilities?.appleParavirtualizedGraphicsSupported ?? false

            if (virtualMachine.os == QemuConstants.OS_LINUX || virtualMachine.os == QemuConstants.OS_WIN) && virGLSupported ||
                virtualMachine.os == QemuConstants.OS_MAC && Utils.isMacVMSupportingParavirtualizedGraphics(virtualMachine) && appleParavirtualizedGraphicsSupported
            {
                print("3D Acceleration SUPPORTED")
                DispatchQueue.main.async {
                    self.accelerationSupported = true
                }
            } else {
                print("3D Acceleration NOT SUPPORTED")
                DispatchQueue.main.async {
                    self.accelerationSupported = false
                }
            }
        }
    }

    fileprivate func verifySpiceSupport() {
        if let virtualMachine {
            let spiceSupported = QemuCapabilitiesReporter.getInstance(forQemuPath: QemuUtils.getQemuPath(for: virtualMachine))?.spiceSupported ?? false

            if spiceSupported {
                print("Spice SUPPORTED")
                DispatchQueue.main.async {
                    self.spiceSupported = true
                }
            } else {
                print("Spice NOT SUPPORTED")
                DispatchQueue.main.async {
                    self.spiceSupported = false
                }
            }
        }
    }
}
