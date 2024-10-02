//
//  AppDelegate.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var savedVMs: [String]? = [];
    private var rootController: RootViewController?;
    private var fileName: String?
    private var initialized = false

    @IBOutlet weak var vmMenu: NSMenu!
    @IBOutlet weak var startVMMenuItem: NSMenuItem!
    @IBOutlet weak var startVMInRecoveryMenuItem: NSMenuItem!
    @IBOutlet weak var stopVMMenuItem: NSMenuItem!
    @IBOutlet weak var pauseVMMenuItem: NSMenuItem!
    @IBOutlet weak var editVMMenuItem: NSMenuItem!
    @IBOutlet weak var cloneVMMemuItem: NSMenuItem!
    @IBOutlet weak var showVMInFinderMenuItem: NSMenuItem!
    @IBOutlet weak var exportMenuItem: NSMenuItem!
    @IBOutlet weak var exportToParallelsMenuItem: NSMenuItem!
    @IBOutlet weak var importFromParallelsMenuItem: NSMenuItem!
    @IBOutlet weak var convertToQemuMenuItem: NSMenuItem!
    @IBOutlet weak var convertToAppleMenuItem: NSMenuItem!
    
    @IBAction func preferencesMenuBarClicked(_ sender: Any) {
        NSApp.mainWindow?.windowController?.performSegue(withIdentifier: MacMulatorConstants.PREFERENCES_SEGUE, sender: self);
    }
    
    @IBAction func newVMMenuBarClicked(_ sender: Any) {
        NSApp.mainWindow?.windowController?.performSegue(withIdentifier: MacMulatorConstants.NEW_VM_SEGUE, sender: self);
    }
    
    @IBAction func openVMMenuBarClicked(_ sender: Any) {
        Utils.showFileSelector(fileTypes: [MacMulatorConstants.VM_EXTENSION], uponSelection: { panel in
            _ = self.application(NSApp, openFile: String(panel.url!.path)) });
    }
    
    @IBAction func attachUSBImageMenuBarClicked(_ sender: Any) {
        Utils.showFileSelector(fileTypes: Utils.IMAGE_TYPES, uponSelection: { panel in
            if let path = panel.url?.path {
                rootController?.attachUSBImageToVM(MacMulatorConstants.mainMenuSender, path)
            }
        })
    }
    
    @IBAction func exportVMToParallelsMenuBarClicked(_ sender: Any) {
        if #available(macOS 11.0, *) {
            Utils.showDirectorySelector(uponSelection: { panel in
                if let vm = rootController?.currentVm {
                    do {
                        try ImportExportHerlper.exportVmToParallels(vm: vm, destinationPath: panel.url!.path)
                        Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.informational, message: NSLocalizedString("AppDelegate.exportToParallelsComplete", comment: ""))
                    } catch {
                        Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("AppDelegate.exportFailed", comment: ""), error.localizedDescription))
                    }
                }
            })
        }
    }
    
    @IBAction func importVMFromParallelsMenuBarClicked(_ sender: Any) {
        if #available(macOS 11.0, *) {
            Utils.showFileSelector(fileTypes: [ImportExportHerlper.PARALLELS_EXTENSION], uponSelection: { panel in
                do {
                    let vm = try ImportExportHerlper.importVmFromParallels(sourcePath: panel.url!.path)
                    rootController?.addVirtualMachine(vm)
                } catch {
                    Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("AppDelegate.importFailed", comment: ""), error.localizedDescription))
                }
            })
        }
    }
    
    @IBAction func convertToQemuMenuBarClicked(_ sender: Any) {
        if #available(macOS 13.0, *) {
            rootController?.convertToQemuMenuBarClicked(MacMulatorConstants.mainMenuSender)
            refreshVMMenus()
        }
    }
    
    @IBAction func convertToAppleMenuBarClicked(_ sender: Any) {
        if #available(macOS 13.0, *) {
            rootController?.convertToAppleMenuBarClicked(MacMulatorConstants.mainMenuSender)
            refreshVMMenus()
        }
    }
    
    @IBAction func startVMMenuBarClicked(_ sender: Any) {
        rootController?.startVMMenuBarClicked(MacMulatorConstants.mainMenuSender);
    }
    
    @IBAction func startVMInRecoveryMenuBarClicked(_ sender: Any) {
        rootController?.startVMInRecoveryMenuBarClicked(MacMulatorConstants.mainMenuSender)
    }
    
    @IBAction func stopVMMenubarClicked(_ sender: Any) {
        rootController?.stopVMMenubarClicked(MacMulatorConstants.mainMenuSender);
    }
    
    @IBAction func editVMmenuBarClicked(_ sender: Any) {
        rootController?.editVMmenuBarClicked(MacMulatorConstants.mainMenuSender);
    }
    
    @IBAction func showConsolemenuBarClicked(_ sender: Any) {
        rootController?.showConsoleMenubarClicked(MacMulatorConstants.mainMenuSender);
    }
    
    @IBAction func pauseVMMenuBarClicked(_ sender: Any) {
        rootController?.pauseVMMenuBarClicked(MacMulatorConstants.mainMenuSender)
    }
    
    @IBAction func cloneVMMenuBarClicked(_ sender: Any) {
        rootController?.cloneVMMenuBarClicked(MacMulatorConstants.mainMenuSender)
    }
    
    @IBAction func showVMInFinderMenuBarClicked(_ sender: Any) {
        rootController?.showVMInFinderMenuBarClicked(MacMulatorConstants.mainMenuSender)
    }

    func refreshVMMenus() {
        vmMenu.autoenablesItems = false
        
        if let rootController = self.rootController {
            
            #if arch(x86_64)
            startVMInRecoveryMenuItem.isHidden = true
            #endif
            
            if rootController.currentVm == nil {
                pauseVMMenuItem.isEnabled = false
                startVMMenuItem.isEnabled = false
                startVMInRecoveryMenuItem.isEnabled = false
                stopVMMenuItem.isEnabled = false
                editVMMenuItem.isEnabled = false
                cloneVMMemuItem.isEnabled = false
                showVMInFinderMenuItem.isEnabled = false
                exportMenuItem.isEnabled = false
                convertToQemuMenuItem.isEnabled = false
                convertToAppleMenuItem.isEnabled = false
            } else {
                let vm = rootController.currentVm
                if let vm = vm {
                    cloneVMMemuItem.isEnabled = true
                    showVMInFinderMenuItem.isEnabled = true
                    
                    if rootController.isCurrentVMRunning() {
                        pauseVMMenuItem.isEnabled = Utils.isPauseSupported(vm)
                        startVMMenuItem.isEnabled = false
                        #if arch(arm64)
                        startVMInRecoveryMenuItem.isEnabled = false
                        #endif
                        stopVMMenuItem.isEnabled = true
                    } else {
                        pauseVMMenuItem.isEnabled = false
                        startVMMenuItem.isEnabled = Utils.isVMAvailable(vm)
                        #if arch(arm64)
                        startVMInRecoveryMenuItem.isEnabled = Utils.isFullFeaturedMacOSVM(vm)
                        #endif
                        stopVMMenuItem.isEnabled = false
                    }
                    
                    #if arch(arm64)
                        importFromParallelsMenuItem.isEnabled = true
                        if Utils.isFullFeaturedMacOSVM(vm) {
                            exportMenuItem.isEnabled = true
                            exportToParallelsMenuItem.isEnabled = true
                        } else {
                            exportMenuItem.isEnabled = false
                            exportToParallelsMenuItem.isEnabled = false
                        }
                    #else
                        exportMenuItem.isEnabled = false
                        exportToParallelsMenuItem.isEnabled = false
                        importFromParallelsMenuItem.isEnabled = true
                    #endif

                    if vm.type == MacMulatorConstants.APPLE_VM {
                        convertToQemuMenuItem.isEnabled = !Utils.isMacVMWithOSVirtualizationFramework(os: vm.os, subtype: vm.subtype)
                        convertToAppleMenuItem.isEnabled = false
                    } else {
                        convertToQemuMenuItem.isEnabled = false
                        convertToAppleMenuItem.isEnabled = vm.os == QemuConstants.OS_LINUX
                    }

                }
            }
        }
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if (performSanityCheck(filename)) {
            if initialized {
                rootController?.addVirtualMachineFromFile(filename);
            } else {
                self.fileName = filename
            }
            return true;
        } else {
            Utils.showAlert(window: sender.mainWindow!, style: NSAlert.Style.warning, message: String(format: NSLocalizedString("AppDelegate.cannotOpenFile", comment: ""), filename));
            return false;
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let userDefaults = UserDefaults.standard;

        setupDefaultsPreferences(userDefaults)

        self.savedVMs = userDefaults.stringArray(forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS);
        if self.savedVMs == nil {
            self.savedVMs = [];
        }
        
        setupSavedVMs();
        
        initialized = true
        
        if let fileName = fileName {
            rootController?.addVirtualMachineFromFile(fileName);
        }
    }
    
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let rootController = self.rootController {
            if rootController.areThereRunningVMs() {
                let response = Utils.showPrompt(window: rootController.view.window!, style: NSAlert.Style.warning, message: NSLocalizedString("AppDelegate.youHaveRunningVMs", comment: ""));
                if response.rawValue != Utils.ALERT_RESP_OK {
                    return NSApplication.TerminateReply.terminateCancel;
                } else {
                    rootController.killAllRunningVMs();
                }
            }
        }
        
        return .terminateNow
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        let userDefaults = UserDefaults.standard;
        userDefaults.set(savedVMs, forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS);
        
        // Useful in Development to replicate the startup of a clean installation of MacMulator
        // resetDefaults();
    }
    
    fileprivate func resetDefaults() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true;
    }
    
    func rootControllerDidFinishLoading(_ rootController: RootViewController) {
        self.rootController = rootController;
        self.refreshVMMenus()
    }
    
    func addSavedVM(_ savedVM: String) {
        let vmToSave = Utils.unescape(savedVM);
        if !(savedVMs!.contains(vmToSave)) {
            savedVMs!.append(vmToSave);
        }
        
        let userDefaults = UserDefaults.standard;
        userDefaults.set(savedVMs, forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS);
    }
    
    func removeSavedVM(_ savedVM: String) {
        let vmToRemove = Utils.unescape(savedVM);
        let index = (savedVMs?.firstIndex(of: vmToRemove))!;
        savedVMs?.remove(at: index);
        
        let fileManager = FileManager.default;
        do {
            try fileManager.removeItem(at: URL(fileURLWithPath: savedVM));
        } catch {
            print(String(format: NSLocalizedString("AppDelegate.errorDeleting", comment: ""), savedVM, error.localizedDescription));
        }

        
        let userDefaults = UserDefaults.standard;
        userDefaults.set(savedVMs, forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS);
    }
    
    func moveSavedVm(at originalRow: Int, to newRow: Int) {
        let vm = savedVMs?.remove(at: originalRow);
        savedVMs?.insert(vm!, at: newRow);
        
        let userDefaults = UserDefaults.standard;
        userDefaults.set(savedVMs, forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS);
    }
    
    fileprivate func setupSavedVMs() {
        let filemanager = FileManager.default
        var toRemove: [Int] = []
        for savedVM in savedVMs! {
            if filemanager.fileExists(atPath: savedVM) && performSanityCheck(savedVM) {
                rootController?.addVirtualMachineFromFile(savedVM)
            } else {
                toRemove.append((savedVMs?.lastIndex(of: savedVM))!)
            }
        }
        
        if let controller = rootController, controller.getVirtualMachinesCount() > 0 {
            rootController?.setCurrentVirtualMachine(rootController?.virtualMachines[0]);
        }
        
        if (toRemove.count > 0) {
            var removed:[String] = [];
            toRemove.reverse();
            for index in toRemove {
                removed.append((savedVMs?.remove(at: index))!);
            }
            
            Utils.showAlert(window: (rootController?.view.window)!, style: NSAlert.Style.informational, message: String(format: NSLocalizedString("AppDelegate.couldNotFindExistingVMs", comment: ""), removed.joined(separator: ", ")));

            let userDefaults = UserDefaults.standard;
            userDefaults.set(savedVMs, forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS);
        }
    }
    
    fileprivate func performSanityCheck(_ filename: String) -> Bool{
        if (filename.hasSuffix("." + MacMulatorConstants.VM_EXTENSION)) {
            
            let fileManager = FileManager.default;
            do {
                let fileNames: [String] = try fileManager.contentsOfDirectory(atPath: filename);
                for file in fileNames {
                    if (file == MacMulatorConstants.INFO_PLIST) {
                        return true;
                    }
                }
            } catch {
                print(String(format: NSLocalizedString("AppDelegate.errorReading", comment: ""), filename, error.localizedDescription));
            }
        }
        
        return false;
    }
    
    fileprivate func setupDefaultsPreferences(_ userDefaults: UserDefaults) {
        if userDefaults.value(forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH) == nil {
            userDefaults.set(Utils.getDefaultVmFolderPath(), forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH);
        }
        if userDefaults.value(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH) == nil {
            userDefaults.set(Utils.getDefaultQemuFolderPath(), forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH);
        }
        if userDefaults.value(forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE) == nil {
            userDefaults.set(10, forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE);
        }
        if userDefaults.value(forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED) == nil {
            userDefaults.set(false, forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED);
        }
    }
}

