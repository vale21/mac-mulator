//
//  PreferencesViewController.swift
//  MacMulator
//
//  Created by Vale on 22/04/21.
//

import Cocoa

class PreferencesViewController: NSViewController, NSTextFieldDelegate {
    
    @IBOutlet weak var vmFolderField: NSTextField!
    @IBOutlet weak var qemuFolderField: NSTextField!
    @IBOutlet weak var vmFolderButton: NSButton!
    @IBOutlet weak var qemuFolderButton: NSButton!
    
    @IBOutlet weak var qemuVersionLabel: NSTextField!
    @IBOutlet weak var swtpm_tick: NSImageView!
    @IBOutlet weak var qemu_img_tick: NSImageView!
    @IBOutlet weak var qemu_img_label: NSTextField!
    @IBOutlet weak var qemu_i386_tick: NSImageView!
    @IBOutlet weak var qemu_x86_64_tick: NSImageView!
    @IBOutlet weak var qemu_arm_tick: NSImageView!
    @IBOutlet weak var qemu_arm64_tick: NSImageView!
    @IBOutlet weak var qemu_ppc_tick: NSImageView!
    @IBOutlet weak var qemu_68k_tick: NSImageView!
    
    @IBOutlet weak var livePreviewEnabledButton: NSButton!
    @IBOutlet weak var livePreviewLabel: NSTextField!
    @IBOutlet weak var oneSecLabel: NSTextField!
    @IBOutlet weak var sixtySecsLabel: NSTextField!
    @IBOutlet weak var livePreviewSlider: NSSlider!
    
    var userDefaults: UserDefaults = UserDefaults.standard;
    var rootController : RootViewController?
    var qemuVersion : String?
    var dirty = false;
    
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    @IBAction func searchFolder(_ sender: Any) {
        Utils.showDirectorySelector(uponSelection: {
            panel in
            if sender as? NSObject == vmFolderButton {
                vmFolderField.stringValue = panel.url!.path;
                userDefaults.set(Utils.escape(vmFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH);
            } else if sender as? NSObject == qemuFolderButton {
                qemuFolderField.stringValue = panel.url!.path;
                userDefaults.set(Utils.escape(qemuFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH);
                checkForQemuBinaries();
            }
            dirty = true;
        });
    }
    
    @IBAction func livePreviewTickChanged(_ sender: Any) {
        let button = sender as! NSButton;
        
        if button.state == NSControl.StateValue.off {
            livePreviewLabel.textColor = NSColor.tertiaryLabelColor;
            oneSecLabel.textColor = NSColor.tertiaryLabelColor;
            sixtySecsLabel.textColor = NSColor.tertiaryLabelColor;
            livePreviewSlider.isEnabled = false;
        } else {
            livePreviewLabel.textColor = NSColor.labelColor;
            oneSecLabel.textColor = NSColor.labelColor;
            sixtySecsLabel.textColor = NSColor.labelColor;
            livePreviewSlider.isEnabled = true;
        }
        
        userDefaults.set(button.state == NSControl.StateValue.on, forKey:MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED);
        dirty = true;
    }
    
    @IBAction func sliderChanged(_ sender: Any) {
        let slider = sender as! NSSlider;
        
        let value = slider.intValue
        livePreviewLabel.stringValue = String(format: NSLocalizedString("PreferencesViewController.updateLivePreview", comment: ""), String(value))
        
        userDefaults.set(value, forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE);
        dirty = true;
    }
    
    override func viewWillAppear() {
        vmFolderField.stringValue = Utils.unescape(userDefaults.string(forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH)!);
        qemuFolderField.stringValue = Utils.unescape(userDefaults.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!);
        
        let livePreviewEnabled = userDefaults.bool(forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED);
        livePreviewEnabledButton.state = livePreviewEnabled ? NSButton.StateValue.on : NSButton.StateValue.off;
        livePreviewTickChanged(livePreviewEnabledButton as Any);
        
        let livePreviewRate = userDefaults.integer(forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE);
        livePreviewLabel.stringValue = String(format: NSLocalizedString("PreferencesViewController.updateLivePreview", comment: ""), String(livePreviewRate))
        livePreviewSlider.intValue = Int32(livePreviewRate);
        
        checkForQemuBinaries();
        dirty = false;
    }
    
    override func viewDidDisappear() {
        if dirty {
            rootController?.refreshViewForVM(rootController?.currentVm);
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSObject == vmFolderField {
            userDefaults.set(Utils.cleanFolderPath(vmFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH);
        } else if obj.object as? NSObject == qemuFolderField {
            userDefaults.set(Utils.cleanFolderPath(qemuFolderField.stringValue), forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH);
        }
        dirty = true;
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if obj.object as? NSObject == qemuFolderField {
            checkForQemuBinaries();
        }
    }
    
    fileprivate func checkForQemuBinaries() {
        let fileManager = FileManager.default;
        let path = qemuFolderField.stringValue
        if fileManager.fileExists(atPath: path) {
            checkFile(QemuConstants.SWTPM, swtpm_tick);
            checkFileAndGetVersion(QemuConstants.QEMU_IMG, qemu_img_tick);
            checkFile(QemuConstants.ARCH_X86, qemu_i386_tick);
            checkFile(QemuConstants.ARCH_X64, qemu_x86_64_tick);
            checkFile(QemuConstants.ARCH_ARM, qemu_arm_tick);
            checkFile(QemuConstants.ARCH_ARM64, qemu_arm64_tick);
            checkFile(QemuConstants.ARCH_PPC, qemu_ppc_tick);
            checkFile(QemuConstants.ARCH_68K, qemu_68k_tick);
        } else {
            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("PreferencesViewController.pathDoesNotExists", comment: ""), path));
            self.qemuVersionLabel.stringValue = NSLocalizedString("PreferencesViewController.noQemuFound", comment: "");
            setYellowCross(qemu_img_tick);
            setRedCross(swtpm_tick);
            setRedCross(qemu_i386_tick);
            setRedCross(qemu_x86_64_tick);
            setRedCross(qemu_arm_tick);
            setRedCross(qemu_arm64_tick);
            setRedCross(qemu_ppc_tick);
            setRedCross(qemu_68k_tick);
        }
    }
    
    fileprivate func checkFile(_ path: String, _ image: NSImageView) {
        if QemuUtils.isBinaryAvailable(path) {
            setGreenTick(image);
        } else if path == QemuConstants.QEMU_IMG {
            setYellowCross(image);
        } else {
            setRedCross(image);
        }
    }
    
    fileprivate func checkFileAndGetVersion(_ path: String, _ image: NSImageView) {
        checkFile(path, image);
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)
        QemuUtils.getQemuVersion(qemuPath: qemuPath!, uponCompletion: { version in
            DispatchQueue.main.async {
                if version == nil {
                    self.qemuVersionLabel.stringValue = NSLocalizedString("PreferencesViewController.noQemuFound", comment: "");
                } else {
                    self.qemuVersionLabel.stringValue = String(format: NSLocalizedString("PreferencesViewController.qemuFound", comment: ""), version!);
                }
            }
        });
    }
    
    fileprivate func setGreenTick(_ view: NSImageView) {
        if #available(macOS 11, *) {
            view.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil);
            view.contentTintColor = NSColor.systemGreen;
        } else {
            view.image = NSImage(named: "checkmark.circle.fill");
        }
    }
    
    fileprivate func setYellowCross(_ view: NSImageView) {
        if #available(macOS 11, *) {
            view.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil);
            view.contentTintColor = NSColor.systemYellow;
        } else {
            view.image = NSImage.init(named: NSImage.Name("xmark.circle.fill.yellow"));
        }
    }
    
    fileprivate func setRedCross(_ view: NSImageView) {
        if #available(macOS 11, *) {
            view.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil);
            view.contentTintColor = NSColor.systemRed;
        } else {
            view.image = NSImage(named: "xmark.circle.fill");
        }
    }
}
