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

    func setRootController(_ rootController: RootViewController) {
        self.rootController = rootController
    }

    @IBAction func searchFolder(_ sender: Any) {
        Utils.showDirectorySelector(uponSelection: {
            panel in
            if sender as? NSObject == vmFolderButton {
                vmFolderField.stringValue = panel.url!.path
            } else if sender as? NSObject == qemuFolderButton {
                qemuFolderField.stringValue = panel.url!.path
                WorkspaceState.shared.qemuPath = Utils.escape(qemuFolderField.stringValue)
            }
            dirty = true
        })
    }

    @IBAction func sliderChanged(_ sender: Any) {
        let slider = sender as! NSSlider

        let value = slider.intValue

        WorkspaceState.shared.livePreviewRate = Int(value)
        dirty = true
    }

    override func viewWillAppear() {
        view.window?.title = NSLocalizedString("PreferencesViewController.windowTitle", comment: "")
        vmFolderLabel.stringValue = NSLocalizedString("PreferencesViewController.vmFolderLabel", comment: "")
        vmFolderField.stringValue = Utils.getParentDir(WorkspaceState.shared.filePath)
        initialStateFilePath = WorkspaceState.shared.filePath
        vmFolderButton.title = NSLocalizedString("PreferencesViewController.find", comment: "")
        qemuFolderLabel.stringValue = NSLocalizedString("PreferencesViewController.qemuFolderLabel", comment: "")
        qemuFolderField.stringValue = Utils.unescape(WorkspaceState.shared.qemuPath)
        qemuFolderButton.title = NSLocalizedString("PreferencesViewController.find", comment: "")
        viewQemuCapabilitiesButton.title = NSLocalizedString("PreferencesViewController.viewQemuCapabilities", comment: "")

        let capabilities = QemuCapabilitiesReporter.getInstance(forQemuPath: QemuUtils.getQemuPath())
        updateView(with: capabilities)
    }

    override func viewDidDisappear() {
        WorkspaceState.shared.save()

        let stateFilePath = Utils.cleanFolderPath(vmFolderField.stringValue) + "/" + MacMulatorConstants.APP_STATE_FILE
        if stateFilePath != initialStateFilePath {
            // Switch once the Preferences window is gone: prompting while it is still closing does not work.
            DispatchQueue.main.async {
                self.vmFolderChanged(stateFilePath: stateFilePath)
            }
        }
        if dirty {
            rootController?.refreshViewForVM(rootController?.currentVm)
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSObject == qemuFolderField {
            WorkspaceState.shared.qemuPath = Utils.cleanFolderPath(qemuFolderField.stringValue)
        }
        dirty = true
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if obj.object as? NSObject == qemuFolderField {
            let capabilities = QemuCapabilitiesReporter.getInstance(forQemuPath: qemuFolderField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
            updateView(with: capabilities)
        }
    }

    private func vmFolderChanged(stateFilePath: String) {
        guard let appDelegate = NSApp.delegate as? AppDelegate,
              let rootController = appDelegate.rootController,
              let window = rootController.view.window
        else { return }

        let handle: FileHandle
        switch WorkspaceState.lockStateFile(atPath: stateFilePath) {
        case let .locked(lockedHandle):
            handle = lockedHandle
        case .inUse:
            restoreVmFolder()
            Utils.showAlert(window: window, style: NSAlert.Style.warning, message: String(format: NSLocalizedString("PreferencesViewController.workspaceInUse", comment: ""), Utils.getParentDir(stateFilePath)), virtualMachine: nil)
            return
        case let .failed(reason):
            restoreVmFolder()
            Utils.showAlert(window: window, style: NSAlert.Style.warning, message: String(format: NSLocalizedString("AppDelegate.workspaceNotAccessible", comment: ""), Utils.getParentDir(stateFilePath), reason), virtualMachine: nil)
            return
        }

        guard rootController.areThereRunningVMs() else {
            WorkspaceState.shared.open(handle, atPath: stateFilePath)
            rememberWorkspaceSelection(atPath: stateFilePath)
            appDelegate.reloadSavedVMs()
            return
        }

        Utils.showPrompt(window: window, style: NSAlert.Style.warning, message: NSLocalizedString("PreferencesViewController.vmFolderChangedWithRunningVMs", comment: ""), completionHandler: { response in
            if response == .alertFirstButtonReturn {
                let runners = Array(rootController.runningVMs.values)
                guard !runners.isEmpty else {
                    WorkspaceState.shared.open(handle, atPath: stateFilePath)
                    appDelegate.reloadSavedVMs()
                    return
                }

                var remainingRunners = runners.count
                var stopError: Error?
                for runner in runners {
                    runner.stopVM(guestStopped: true) { error in
                        DispatchQueue.main.async {
                            if stopError == nil {
                                stopError = error
                            }
                            remainingRunners -= 1
                            guard remainingRunners == 0 else { return }

                            if let stopError {
                                self.restoreVmFolder()
                                let message = String(format: NSLocalizedString("PreferencesViewController.workspaceSwitchFailed", comment: ""), stopError.localizedDescription)
                                Utils.showAlert(window: window, style: .warning, message: message, virtualMachine: nil)
                            } else {
                                WorkspaceState.shared.open(handle, atPath: stateFilePath)
                                self.rememberWorkspaceSelection(atPath: stateFilePath)
                                appDelegate.reloadSavedVMs()
                            }
                        }
                    }
                }
            } else {
                // The handle is dropped with this closure, releasing the lock on the new workspace.
                self.restoreVmFolder()
            }
        }, virtualMachine: nil)
    }

    private func restoreVmFolder() {
        vmFolderField.stringValue = Utils.getParentDir(WorkspaceState.shared.filePath)
    }

    private func rememberWorkspaceSelection(atPath stateFilePath: String) {
        userDefaults.set(Utils.escape(Utils.getParentDir(stateFilePath)), forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH)
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
