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
    
    @IBAction func preferencesMenuBarClicked(_ sender: Any) {
        NSApp.mainWindow?.windowController?.performSegue(withIdentifier: MacMulatorConstants.PREFERENCES_SEGUE, sender: self);
    }
    
    @IBAction func newVMMenuBarClicked(_ sender: Any) {
        NSApp.mainWindow?.windowController?.performSegue(withIdentifier: MacMulatorConstants.NEW_VM_SEGUE, sender: self);
    }
    
    @IBAction func openVMMenuBarClicked(_ sender: Any) {
        Utils.showFileSelector(fileTypes: [MacMulatorConstants.VM_EXTENSION], uponSelection: { panel in self.application(NSApp, openFile: String(panel.url!.path)) });
    }
        
    @IBAction func startVMMenuBarClicked(_ sender: Any) {
        rootController?.startVMMenuBarClicked(sender);
    }
    
    @IBAction func startVMInRecoveryMenuBarClicked(_ sender: Any) {
        rootController?.startVMInRecoveryMenuBarClicked(sender)
    }
    
    @IBAction func stopVMMenubarClicked(_ sender: Any) {
        rootController?.stopVMMenubarClicked(sender);
    }
    
    @IBAction func editVMmenuBarClicked(_ sender: Any) {
        rootController?.editVMmenuBarClicked(sender);
    }
    
    @IBAction func showConsolemenuBarClicked(_ sender: Any) {
        rootController?.showConsoleMenubarClicked(sender);
    }
    
    func refreshVMMenus() {
        pauseVMMenuItem.isEnabled = false
        if let rootController = self.rootController {
            if rootController.currentVm == nil {
                startVMMenuItem.isEnabled = false
                startVMInRecoveryMenuItem.isEnabled = false
                stopVMMenuItem.isEnabled = false
                editVMMenuItem.isEnabled = false
            } else {
                let vm = rootController.currentVm
                if let vm = vm {
                    if rootController.isCurrentVMRunning() {
                        startVMMenuItem.isEnabled = false
                        startVMInRecoveryMenuItem.isEnabled = false
                        stopVMMenuItem.isEnabled = true
                    } else {
                        startVMMenuItem.isEnabled = Utils.isVMAvailable(vm)
                        startVMInRecoveryMenuItem.isEnabled = Utils.isRecoveryModeSupported(vm)
                        stopVMMenuItem.isEnabled = false
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
            Utils.showAlert(window: sender.mainWindow!, style: NSAlert.Style.warning,
                            message: "Could not open file " + filename + ". It migh be corrupted.");
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
                let response = Utils.showPrompt(window: rootController.view.window!, style: NSAlert.Style.warning, message: "You have running VMs.\nClosing MacMulator will forcibly kill any running VM.\nIt is strogly suggested to shut it down gracefully using the guest OS shut down procedure, or you might loose your unsaved work.\n\nDo you want to continue?");
                if response.rawValue != Utils.ALERT_RESP_OK {
                    return NSApplication.TerminateReply.terminateCancel;
                } else {
                    rootController.killAllRunningVMs();
                }
            }
        }
        
        return NSApplication.TerminateReply.terminateNow;
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
            print("ERROR while deleting" + savedVM + ": " + error.localizedDescription);
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
        let filemanager = FileManager.default;
        var toRemove: [Int] = [];
        for savedVM in savedVMs! {
            if filemanager.fileExists(atPath: savedVM) && performSanityCheck(savedVM) {
                rootController?.addVirtualMachineFromFile(savedVM);
            } else {
                toRemove.append((savedVMs?.lastIndex(of: savedVM))!);
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
            
            Utils.showAlert(window: (rootController?.view.window)!, style: NSAlert.Style.informational, message: "Could not find some Virtual Machines that were configured in MacMulator: " + removed.joined(separator: ", "));

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
                print("ERROR while reading" + filename + ": " + error.localizedDescription);
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

