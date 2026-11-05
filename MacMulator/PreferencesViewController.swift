//
//  PreferencesViewController.swift
//  MacMulator
//
//  Created by Vale on 22/04/21.
//

import Cocoa

class PreferencesViewController: NSViewController, NSTextFieldDelegate {
    @IBOutlet var vmFolderLabel: NSTextField!
    @IBOutlet var vmFolderField: NSTextField!
    @IBOutlet var qemuFolderLabel: NSTextField!
    @IBOutlet var qemuFolderField: NSTextField!
    @IBOutlet var vmFolderButton: NSButton!
    @IBOutlet var qemuFolderButton: NSButton!
    @IBOutlet var qemuVersionLabel: NSTextField!

    @IBOutlet var qemuIntelIndicator: NSImageView!
    @IBOutlet var qemuArmIndicator: NSImageView!
    @IBOutlet var virGLRendererIndicator: NSImageView!
    @IBOutlet var spiceIndicator: NSImageView!

    @IBOutlet var viewQemuCapabilitiesButton: NSButton!

    var userDefaults: UserDefaults = .standard
    var rootController: RootViewController?
    var qemuVersion: String?
    var dirty = false
    private var initialStateFilePath: String?
    private var initialVmFolderPreference: String?

    func setRootController(_ rootController: RootViewController) {
        self.rootController = rootController
    }

    @IBAction func searchFolder(_ sender: Any) {
        Utils.showDirectorySelector(uponSelection: {
            panel in
            if sender as? NSObject == vmFolderButton {
                vmFolderField.stringValue = panel.url!.path
                userDefaults.set(Utils.escape(vmFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH)
            } else if sender as? NSObject == qemuFolderButton {
                qemuFolderField.stringValue = panel.url!.path
                userDefaults.set(Utils.escape(qemuFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)
            }
            dirty = true
        })
    }

    @IBAction func sliderChanged(_ sender: Any) {
        let slider = sender as! NSSlider

        let value = slider.intValue

        userDefaults.set(value, forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE)
        dirty = true
    }

    override func viewWillAppear() {
        view.window?.title = NSLocalizedString("PreferencesViewController.windowTitle", comment: "")
        vmFolderLabel.stringValue = NSLocalizedString("PreferencesViewController.vmFolderLabel", comment: "")
        vmFolderField.stringValue = Utils.unescape(userDefaults.string(forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH)!)
        initialStateFilePath = Utils.getAppStateFilePath()
        initialVmFolderPreference = userDefaults.string(forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH)
        vmFolderButton.title = NSLocalizedString("PreferencesViewController.find", comment: "")
        qemuFolderLabel.stringValue = NSLocalizedString("PreferencesViewController.qemuFolderLabel", comment: "")
        qemuFolderField.stringValue = Utils.unescape(userDefaults.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!)
        qemuFolderButton.title = NSLocalizedString("PreferencesViewController.find", comment: "")
        viewQemuCapabilitiesButton.title = NSLocalizedString("PreferencesViewController.viewQemuCapabilities", comment: "")

        let capabilities = QemuCapabilitiesReporter.getInstance(forQemuPath: QemuUtils.getQemuPath())
        updateView(with: capabilities)
    }

    override func viewDidDisappear() {
        // The VM list is stored in the VMs folder: when the folder changes, show the VMs saved in the new one.
        if Utils.getAppStateFilePath() != initialStateFilePath {
            vmFolderChanged()
        }
        if dirty {
            rootController?.refreshViewForVM(rootController?.currentVm)
        }
    }

    /// Switching the VMs folder replaces the VM list, so the running VMs of the current list are forcibly stopped.
    /// The user is warned first: if they cancel, the previous VMs folder is restored.
    private func vmFolderChanged() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        if let rootController = appDelegate.rootController, rootController.areThereRunningVMs() {
            guard let window = rootController.view.window else { return }
            let response = Utils.showPrompt(window: window, style: NSAlert.Style.warning, message: NSLocalizedString("PreferencesViewController.vmFolderChangedWithRunningVMs", comment: ""), virtualMachine: nil)
            if response.rawValue != Utils.ALERT_RESP_OK {
                userDefaults.set(initialVmFolderPreference, forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH)
                return
            }
            rootController.killAllRunningVMs()
        }
        appDelegate.reloadSavedVMs()
    }

    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSObject == vmFolderField {
            userDefaults.set(Utils.cleanFolderPath(vmFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH)
        } else if obj.object as? NSObject == qemuFolderField {
            userDefaults.set(Utils.cleanFolderPath(qemuFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)
        }
        dirty = true
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if obj.object as? NSObject == qemuFolderField {
            let capabilities = QemuCapabilitiesReporter.getInstance(forQemuPath: qemuFolderField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
            updateView(with: capabilities)
        }
    }

    private func updateView(with capabilities: QemuCapabilitiesReporter?) {
        refreshQemuVersion(with: capabilities)

        setIndicator(qemuIntelIndicator, capabilities?.hasx86_64Binary ?? false)
        setIndicator(qemuArmIndicator, capabilities?.hasAarch64Binary ?? false)
        setIndicator(virGLRendererIndicator, capabilities?.virGLSupported ?? false)
        setIndicator(spiceIndicator, capabilities?.spiceSupported ?? false)
    }

    private func refreshQemuVersion(with capabilities: QemuCapabilitiesReporter?) {
        if let version = capabilities?.qemuVersion, !version.isEmpty {
            qemuVersionLabel.stringValue = String(format: NSLocalizedString("PreferencesViewController.qemuVersion", comment: ""), version)
        } else {
            qemuVersionLabel.stringValue = NSLocalizedString("PreferencesViewController.qemuNotFound", comment: "")
        }
    }

    private func setIndicator(_ view: NSImageView, _ value: Bool) {
        if value {
            setGreenTick(view)
        } else {
            setRedCross(view)
        }
    }

    private func setGreenTick(_ view: NSImageView) {
        if #available(macOS 11, *) {
            view.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
            view.contentTintColor = NSColor.systemGreen
        } else {
            view.image = NSImage(named: "checkmark.circle.fill")
        }
    }

    private func setRedCross(_ view: NSImageView) {
        if #available(macOS 11, *) {
            view.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
            view.contentTintColor = NSColor.systemRed
        } else {
            view.image = NSImage(named: "xmark.circle.fill")
        }
    }
}
