//
//  EditVMViewControllerAdvanced.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewControllerAdvanced: NSViewController, NSTextFieldDelegate, NSTextViewDelegate {
    @IBOutlet var qemuPathLabel: NSTextField!
    @IBOutlet var qemuPathView: NSTextField!
    @IBOutlet var accelerateVM: NSButton!
    @IBOutlet var qemuPathButton: NSButton!
    @IBOutlet var qemuCommandLabel: NSTextField!
    @IBOutlet var qemuCommandDescription: NSTextField!
    @IBOutlet var fullCommandView: NSTextView!

    var virtualMachine: VirtualMachine?

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        updateView()
    }

    @IBAction func findButtonClicked(_: Any) {
        Utils.showDirectorySelector(uponSelection: {
            panel in
            if let path = panel.url?.path {
                qemuPathView.stringValue = path
                virtualMachine?.qemuPath = path
                updateView()
            }
        })
    }

    @IBAction func accelerateToggleChanged(_: Any) {
        if let virtualMachine {
            virtualMachine.hvf = accelerateVM.state == NSButton.StateValue.on
            updateQemuCommand(virtualMachine)
        }
    }

    override func viewWillAppear() {
        qemuPathLabel.stringValue = NSLocalizedString("EditVMViewControllerAdvanced.qemuPathLabel", comment: "")
        accelerateVM.title = NSLocalizedString("EditVMViewControllerAdvanced.accelerateVM", comment: "")
        qemuPathButton.title = NSLocalizedString("EditVMViewControllerAdvanced.qemuPathButton", comment: "")
        qemuCommandLabel.stringValue = NSLocalizedString("EditVMViewControllerAdvanced.qemuCommandLabel", comment: "")
        qemuCommandDescription.stringValue = NSLocalizedString("EditVMViewControllerAdvanced.qemuCommandDescription", comment: "")

        updateView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        #if APPSTORE
            // The App Store flavor always runs the bundled Qemu: a per-VM Qemu path makes no sense.
            qemuPathLabel.isHidden = true
            qemuPathView.isHidden = true
            qemuPathButton.isHidden = true
            collapseQemuPathSpace()
        #endif
    }

    #if APPSTORE
        /// Hidden views still take part in Auto Layout, so the controls anchored below the Qemu path field
        /// are re-anchored to fill the space left by the hidden Qemu path controls.
        fileprivate func collapseQemuPathSpace() {
            let anchoredToPathField = view.constraints.filter {
                ($0.firstItem === accelerateVM || $0.firstItem === qemuCommandLabel) &&
                    $0.firstAttribute == .top &&
                    $0.secondItem === qemuPathView
            }
            NSLayoutConstraint.deactivate(anchoredToPathField)

            NSLayoutConstraint.activate([
                accelerateVM.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
                qemuCommandLabel.topAnchor.constraint(equalTo: accelerateVM.bottomAnchor, constant: 24),
            ])
        }
    #endif

    fileprivate func updateQemuCommand(_ virtualMachine: VirtualMachine) {
        let runner = QemuRunner(listenPort: 4444, virtualMachine: virtualMachine)
        fullCommandView.string = runner.getQemuCommand()
        qemuPathView.stringValue = QemuUtils.getQemuPath(for: virtualMachine)
    }

    fileprivate func updateView() {
        if let virtualMachine {
            updateQemuCommand(virtualMachine)

            let vmArchitecture = Utils.getMachineArchitecture(virtualMachine.architecture)

            if Utils.hostArchitecture() != vmArchitecture || Utils.isRunningInEmulation() {
                accelerateVM.state = NSButton.StateValue.off
                accelerateVM.isEnabled = false
                if Utils.isRunningInEmulation() {
                    accelerateVM.toolTip = NSLocalizedString("EditVMViewControllerAdvanced.rosettaNotAvailable", comment: "")
                } else {
                    accelerateVM.toolTip = String(format: NSLocalizedString("EditVMViewControllerAdvanced.featureNotAvailable", comment: ""), vmArchitecture, Utils.hostArchitecture() ?? "")
                }
            } else {
                accelerateVM.isEnabled = true
                if let hvf = virtualMachine.hvf {
                    accelerateVM.state = hvf ? NSButton.StateValue.on : NSButton.StateValue.off
                } else {
                    accelerateVM.state = Utils.getAccelForSubType(virtualMachine.os, virtualMachine.subtype) ? NSButton.StateValue.on : NSButton.StateValue.off
                }
            }
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        if (notification.object as! NSTextField) == qemuPathView {
            if let virtualMachine {
                let originalPath = QemuUtils.getQemuPath()

                if qemuPathView.stringValue != originalPath {
                    if qemuPathView.stringValue != "" {
                        virtualMachine.qemuPath = qemuPathView.stringValue
                    } else {
                        virtualMachine.qemuPath = nil
                    }
                } else {
                    virtualMachine.qemuPath = nil
                }
            }
        }

        updateView()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if (notification.object as! NSTextField) == qemuPathView, let virtualMachine, virtualMachine.qemuPath != nil {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: qemuPathView.stringValue) {
                Task {
                    _ = await QemuCapabilitiesReporter.getInstance(forQemuPath: qemuPathView.stringValue)
                }
            } else {
                Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("PreferencesViewController.pathDoesNotExists", comment: ""), qemuPathView.stringValue), virtualMachine: nil)
            }
        }
    }

    func textDidChange(_ notification: Notification) {
        if (notification.object as? NSTextView) == fullCommandView {
            if let virtualMachine {
                let runner = QemuRunner(listenPort: 4444, virtualMachine: virtualMachine)
                let originalCommand = runner.getQemuCommand()

                if fullCommandView.string != originalCommand {
                    if fullCommandView.string != "" {
                        virtualMachine.qemuCommand = fullCommandView.string
                    } else {
                        virtualMachine.qemuCommand = nil
                    }
                } else {
                    virtualMachine.qemuCommand = nil
                }
            }
        }
    }
}
