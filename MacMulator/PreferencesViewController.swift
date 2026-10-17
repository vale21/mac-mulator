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

    @IBOutlet var qemuIntelLabel: NSTextField!
    @IBOutlet var qemuARMLabel: NSTextField!
    @IBOutlet var virGLRendererLabel: NSTextField!
    @IBOutlet var spiceLabel: NSTextField!
    @IBOutlet var viewQemuCapabilitiesButton: NSButton!

    var userDefaults: UserDefaults = .standard
    var rootController: RootViewController?
    var qemuVersion: String?
    var dirty = false

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
        qemuFolderLabel.stringValue = NSLocalizedString("PreferencesViewController.qemuFolderLabel", comment: "")
        qemuFolderField.stringValue = Utils.unescape(userDefaults.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!)

        dirty = false
    }

    override func viewDidDisappear() {
        if dirty {
            rootController?.refreshViewForVM(rootController?.currentVm)
        }
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
            Task {
                _ = await QemuCapabilitiesReporter.getInstance(forQemuPath: qemuFolderField.stringValue)
                (NSApp.delegate as? AppDelegate)?.rootController?.refreshQemuVersion()
            }
        }
    }

    fileprivate func setGreenTick(_ view: NSImageView) {
        if #available(macOS 11, *) {
            view.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
            view.contentTintColor = NSColor.systemGreen
        } else {
            view.image = NSImage(named: "checkmark.circle.fill")
        }
    }

    fileprivate func setYellowCross(_ view: NSImageView) {
        if #available(macOS 11, *) {
            view.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
            view.contentTintColor = NSColor.systemYellow
        } else {
            view.image = NSImage(named: NSImage.Name("xmark.circle.fill.yellow"))
        }
    }

    fileprivate func setRedCross(_ view: NSImageView) {
        if #available(macOS 11, *) {
            view.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
            view.contentTintColor = NSColor.systemRed
        } else {
            view.image = NSImage(named: "xmark.circle.fill")
        }
    }
}
