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
    @IBOutlet var accelDescriptionText: NSTextField!
    @IBOutlet var accelDescriptionLabel: NSTextField!
    @IBOutlet var accelDescriptionSwitch: NSSwitch!
    @IBOutlet var spiceDescriptionText: NSTextField!
    @IBOutlet var spiceDescriptionLabel: NSTextField!
    @IBOutlet var spiceDescriptionSwitch: NSSwitch!
    @IBOutlet var windowsArmDescriptionText: NSTextField!

    var virtualMachine: VirtualMachine?
    var accelerationSuported: Bool = true
    var spiceSuported: Bool = true

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        updateView()
    }

    override func viewWillAppear() {
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

    override func viewDidAppear() {
        verifyOpenGLSupport()
        verifySpiceSuport()
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
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let virtualMachine {
                videoAdapterComboBox.reloadData()
                videoAdapterComboBox.selectItem(at: buildAdaptersList().firstIndex(of: virtualMachine.videoDevice ?? Utils.getVideoForSubType(virtualMachine.os, virtualMachine.subtype)) ?? -1)
                qemuDisplayComboBox.reloadData()
                qemuDisplayComboBox.selectItem(at: QemuConstants.ALL_DISPLAYS.firstIndex(of: virtualMachine.qemuDisplay ?? QemuConstants.DISPLAY_DEFAULT) ?? 0)

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

                if spiceSuported {
                    spiceDescriptionText.isEnabled = true
                    spiceDescriptionLabel.isEnabled = true
                    spiceDescriptionSwitch.isEnabled = true
                    spiceDescriptionSwitch.toolTip = NSLocalizedString("EditVMViewControllerVideo.spiceAvailabilityTooltipEnabled", comment: "")

                    spiceDescriptionSwitch.state = (virtualMachine.enableSpiceDisplay ?? true) ? .on : .off
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
                if Utils.hostArchitecture() != vmArchitecture || Utils.isRunningInEmulation() || !accelerationSuported {
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
        if let virtualMachine {
            if (notification.object as! NSComboBox) == videoAdapterComboBox {
                virtualMachine.videoDevice = buildAdaptersList()[videoAdapterComboBox.indexOfSelectedItem]
            } else if (notification.object as! NSComboBox) == qemuDisplayComboBox {
                virtualMachine.qemuDisplay = QemuConstants.ALL_DISPLAYS[qemuDisplayComboBox.indexOfSelectedItem]
            }
        }
    }

    @IBAction func enable3DAccelerationToggleChanged(_: Any) {
        if let virtualMachine {
            virtualMachine.enable3DAcceleration = accelDescriptionSwitch.state == .on
        }
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
            let shell = Shell()
            let runner = QemuRunner(listenPort: 4444, virtualMachine: virtualMachine)

            if let qemuExecutable = runner.getQemuCommand().split(separator: " ").first {
                let command = qemuExecutable + " -device help"
                print(command)

                shell.runCommand(String(command), virtualMachine.path, uponCompletion: { _ in
                    let devices = shell.readFromStandardOutput()

                    #if APPSTORE
                        // The bundled Qemu only has the Spice display, which cannot provide OpenGL to virtio-gpu-gl.
                        let glDisplayAvailable = false
                    #else
                        let glDisplayAvailable = true
                    #endif
                    if glDisplayAvailable && (virtualMachine.os == QemuConstants.OS_LINUX || virtualMachine.os == QemuConstants.OS_WIN) && (devices.contains("virtio-gpu-gl") || devices.contains("virtio-vga-gl") || devices.contains("ramfb-gl")) || virtualMachine.os == QemuConstants.OS_MAC && Utils.isMacVMSupportingParavirtualozedGraphics(virtualMachine) && devices.contains("apple-gfx-pci") {
                        print("OpenGL SUPPORTED")
                        DispatchQueue.main.async {
                            self.accelerationSuported = true
                            self.updateView()
                        }
                    } else {
                        print("OpenGL NOT SUPPORTED")
                        DispatchQueue.main.async {
                            self.accelerationSuported = false
                            self.updateView()
                        }
                    }
                })
            }
        }
    }

    fileprivate func verifySpiceSuport() {
        if let virtualMachine {
            let shell = Shell()
            let runner = QemuRunner(listenPort: 4444, virtualMachine: virtualMachine)

            if let qemuExecutable = runner.getQemuCommand().split(separator: " ").first {
                let command = qemuExecutable + " -help"
                print(command)

                shell.runCommand(String(command), virtualMachine.path, uponCompletion: { _ in
                    let options = shell.readFromStandardOutput()

                    if options.contains("spice") {
                        print("Spice SUPPORTED")
                        DispatchQueue.main.async {
                            self.spiceSuported = true
                            self.updateView()
                        }
                    } else {
                        print("Spice NOT SUPPORTED")
                        DispatchQueue.main.async {
                            self.spiceSuported = false
                            self.updateView()
                        }
                    }
                })
            }
        }
    }
}
