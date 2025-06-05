//
//  AppDelegate.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var savedVMs: [String]? = []
    private var rootController: RootViewController?
    private var fileName: String?
    private var initialized = false

    @IBOutlet var vmMenu: NSMenu!
    @IBOutlet var importFromParallelsMenuItem: NSMenuItem!
    @IBOutlet var startVMMenuItem: NSMenuItem!
    @IBOutlet var startVMInRecoveryMenuItem: NSMenuItem!
    @IBOutlet var stopVMMenuItem: NSMenuItem!
    @IBOutlet var pauseVMMenuItem: NSMenuItem!
    @IBOutlet var settingsMenuItem: NSMenuItem!
    @IBOutlet var cloneVMMemuItem: NSMenuItem!
    @IBOutlet var showVMInFinderMenuItem: NSMenuItem!
    @IBOutlet var exportMenuItem: NSMenuItem!
    @IBOutlet var exportToParallelsMenuItem: NSMenuItem!
    @IBOutlet var convertToQemuMenuItem: NSMenuItem!
    @IBOutlet var convertToAppleMenuItem: NSMenuItem!
    @IBOutlet var usbDevicesMenuItem: NSMenuItem!
    @IBOutlet var attachImageMenuItem: NSMenuItem!
    @IBOutlet var configureMenuItem: NSMenuItem!
    @IBOutlet var showConsoleOutputmenuItem: NSMenuItem!

    @IBAction func preferencesMenuBarClicked(_: Any) {
        NSApp.mainWindow?.windowController?.performSegue(withIdentifier: MacMulatorConstants.PREFERENCES_SEGUE, sender: self)
    }

    @IBAction func newVMMenuBarClicked(_: Any) {
        NSApp.mainWindow?.windowController?.performSegue(withIdentifier: MacMulatorConstants.NEW_VM_SEGUE, sender: self)
    }

    @IBAction func openVMMenuBarClicked(_: Any) {
        Utils.showFileSelector(fileTypes: [MacMulatorConstants.VM_EXTENSION], uponSelection: { panel in
            _ = self.application(NSApp, openFile: String(panel.url!.path))
        })
    }

    @available(macOS 15.0, *)
    @IBAction func attachUSBImageMenuBarClicked(_: Any) {
        Utils.showFileSelector(fileTypes: Utils.IMAGE_TYPES_USB, uponSelection: { panel in
            if let path = panel.url?.path, let virtualMachine = rootController?.currentVm {
                for virtualDrive in virtualMachine.drives {
                    if virtualDrive.path == path {
                        Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.informational, message: String(format: NSLocalizedString("EditVMViewControllerHardware.imageAlreadyLoaded", comment: ""), path))
                        return
                    }
                }

                let newDrive = VirtualDrive(
                    path: path,
                    name: QemuConstants.MEDIATYPE_USB + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_USB,
                    size: 0
                )
                virtualMachine.drives.append(newDrive)
                virtualMachine.writeToPlist()

                rootController?.attachUSBImageToVM(MacMulatorConstants.mainMenuSender, newDrive)
                refreshVMMenus()
            }
        })
    }

    @available(macOS 15.0, *)
    @IBAction func detachUSBImageMenuBarClicked(_ sender: NSMenuItem) {
        let path = sender.title

        if let virtualMachine = rootController?.currentVm {
            let driveToRemove = virtualMachine.drives.first(where: { drive in drive.path == path })
            if driveToRemove != nil {
                virtualMachine.drives.remove(at: virtualMachine.drives.firstIndex(of: driveToRemove!)!)
                virtualMachine.writeToPlist()

                if rootController?.isVMRunning(virtualMachine) == true {
                    let runner = rootController?.getRunnerForRunningVM(virtualMachine) as! VirtualizationFrameworkVirtualMachineRunner
                    runner.detachUSBImageFromVM(virtualDrive: driveToRemove!)
                }
                refreshVMMenus()
            }
        }
    }

    @IBAction func exportVMToParallelsMenuBarClicked(_: Any) {
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

    @IBAction func importVMFromParallelsMenuBarClicked(_: Any) {
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

    @IBAction func convertToQemuMenuBarClicked(_: Any) {
        if #available(macOS 13.0, *) {
            rootController?.convertToQemuMenuBarClicked(MacMulatorConstants.mainMenuSender)
            refreshVMMenus()
        }
    }

    @IBAction func convertToAppleMenuBarClicked(_: Any) {
        if #available(macOS 13.0, *) {
            rootController?.convertToAppleMenuBarClicked(MacMulatorConstants.mainMenuSender)
            refreshVMMenus()
        }
    }

    @IBAction func startVMMenuBarClicked(_: Any) {
        rootController?.startVMMenuBarClicked(MacMulatorConstants.mainMenuSender)
    }

    @IBAction func startVMInRecoveryMenuBarClicked(_: Any) {
        rootController?.startVMInRecoveryMenuBarClicked(MacMulatorConstants.mainMenuSender)
    }

    @IBAction func stopVMMenubarClicked(_: Any) {
        rootController?.stopVMMenubarClicked(MacMulatorConstants.mainMenuSender)
    }

    @IBAction func editVMmenuBarClicked(_ sender: Any) {
        rootController?.editVMmenuBarClicked(sender) // The sender here determines which tab to show
    }

    @IBAction func showConsolemenuBarClicked(_: Any) {
        rootController?.showConsoleMenubarClicked(MacMulatorConstants.mainMenuSender)
    }

    @IBAction func pauseVMMenuBarClicked(_: Any) {
        rootController?.pauseVMMenuBarClicked(MacMulatorConstants.mainMenuSender)
    }

    @IBAction func cloneVMMenuBarClicked(_: Any) {
        rootController?.cloneVMMenuBarClicked(MacMulatorConstants.mainMenuSender)
    }

    @IBAction func showVMInFinderMenuBarClicked(_: Any) {
        rootController?.showVMInFinderMenuBarClicked(MacMulatorConstants.mainMenuSender)
    }

    func refreshVMMenus() {
        vmMenu.autoenablesItems = false

        if let rootController {
            #if arch(x86_64)
                startVMInRecoveryMenuItem.isHidden = true
            #endif

            if rootController.currentVm == nil {
                pauseVMMenuItem.isEnabled = false
                startVMMenuItem.isEnabled = false
                startVMInRecoveryMenuItem.isEnabled = false
                stopVMMenuItem.isEnabled = false
                settingsMenuItem.isEnabled = false
                cloneVMMemuItem.isEnabled = false
                showVMInFinderMenuItem.isEnabled = false
                exportMenuItem.isEnabled = false
                convertToQemuMenuItem.isEnabled = false
                convertToAppleMenuItem.isEnabled = false
            } else {
                let vm = rootController.currentVm
                if let vm {
                    cloneVMMemuItem.isEnabled = true
                    showVMInFinderMenuItem.isEnabled = true
                    settingsMenuItem.isEnabled = true

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

                        var usbDrives: [String] = []
                        for drive in vm.drives {
                            if drive.mediaType == QemuConstants.MEDIATYPE_USB {
                                usbDrives.append(drive.path)
                            }
                        }

                        if #available(macOS 15.0, *) {
                            usbDevicesMenuItem.isEnabled = true
                            if usbDrives.count > 0 {
                                var detachMenuItem: NSMenuItem
                                if !usbDevicesMenuItem.submenu!.items.contains(where: { item in item.title == NSLocalizedString("AppDelegate.detachImage", comment: "") }) {
                                    detachMenuItem = NSMenuItem(title: NSLocalizedString("AppDelegate.detachImage", comment: ""), action: nil, keyEquivalent: "")
                                    detachMenuItem.submenu = NSMenu(title: NSLocalizedString("AppDelegate.detachImage", comment: ""))
                                    usbDevicesMenuItem.submenu?.insertItem(detachMenuItem, at: 1)
                                } else {
                                    detachMenuItem = usbDevicesMenuItem.submenu!.items.first(where: { item in item.title == NSLocalizedString("AppDelegate.detachImage", comment: "") })!
                                }

                                detachMenuItem.submenu?.removeAllItems()
                                for title in usbDrives {
                                    if !detachMenuItem.submenu!.items.contains(where: { item in item.title == title }) {
                                        detachMenuItem.submenu?.addItem(NSMenuItem(title: title, action: #selector(detachUSBImageMenuBarClicked(_:)), keyEquivalent: ""))
                                    }
                                }
                            } else {
                                if usbDevicesMenuItem.submenu!.items.contains(where: { item in item.title == NSLocalizedString("AppDelegate.detachImage", comment: "") }) {
                                    usbDevicesMenuItem.submenu?.removeItem(at: 1)
                                }
                            }
                        } else {
                            usbDevicesMenuItem.isEnabled = false
                        }
                    } else {
                        convertToQemuMenuItem.isEnabled = false
                        convertToAppleMenuItem.isEnabled = vm.os == QemuConstants.OS_LINUX
                        usbDevicesMenuItem.isEnabled = false
                    }
                }
            }
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if performSanityCheck(filename) {
            if initialized {
                rootController?.addVirtualMachineFromFile(filename)
            } else {
                fileName = filename
            }
            return true
        } else {
            Utils.showAlert(window: sender.mainWindow!, style: NSAlert.Style.warning, message: String(format: NSLocalizedString("AppDelegate.cannotOpenFile", comment: ""), filename))
            return false
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        let userDefaults = UserDefaults.standard

        setupDefaultsPreferences(userDefaults)

        savedVMs = userDefaults.stringArray(forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS)
        if savedVMs == nil {
            savedVMs = []
        }

        setupSavedVMs()

        initialized = true

        if let fileName {
            rootController?.addVirtualMachineFromFile(fileName)
        }
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        if let rootController {
            if rootController.areThereRunningVMs() {
                let response = Utils.showPrompt(window: rootController.view.window!, style: NSAlert.Style.warning, message: NSLocalizedString("AppDelegate.youHaveRunningVMs", comment: ""), virtualMachine: nil)
                if response.rawValue != Utils.ALERT_RESP_OK {
                    return NSApplication.TerminateReply.terminateCancel
                } else {
                    rootController.killAllRunningVMs()
                }
            }
        }

        return .terminateNow
    }

    func applicationWillTerminate(_: Notification) {
        let userDefaults = UserDefaults.standard
        userDefaults.set(savedVMs, forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS)

        // Useful in Development to replicate the startup of a clean installation of MacMulator
        // resetDefaults();
    }

    fileprivate func resetDefaults() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        for key in dictionary.keys {
            defaults.removeObject(forKey: key)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

    func rootControllerDidFinishLoading(_ rootController: RootViewController) {
        self.rootController = rootController
        refreshVMMenus()
    }

    func addSavedVM(_ savedVM: String) {
        let vmToSave = Utils.unescape(savedVM)
        if !(savedVMs!.contains(vmToSave)) {
            savedVMs!.append(vmToSave)
        }

        let userDefaults = UserDefaults.standard
        userDefaults.set(savedVMs, forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS)
    }

    func removeSavedVM(_ savedVM: String) {
        let vmToRemove = Utils.unescape(savedVM)
        let index = (savedVMs?.firstIndex(of: vmToRemove))!
        savedVMs?.remove(at: index)

        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: URL(fileURLWithPath: savedVM))
        } catch {
            print(String(format: NSLocalizedString("AppDelegate.errorDeleting", comment: ""), savedVM, error.localizedDescription))
        }

        let userDefaults = UserDefaults.standard
        userDefaults.set(savedVMs, forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS)
    }

    func moveSavedVm(at originalRow: Int, to newRow: Int) {
        let vm = savedVMs?.remove(at: originalRow)
        savedVMs?.insert(vm!, at: newRow)

        let userDefaults = UserDefaults.standard
        userDefaults.set(savedVMs, forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS)
    }

    fileprivate func setupSavedVMs() {
        let filemanager = FileManager.default
        var toRemove: [Int] = []
        for savedVM in savedVMs! {
            if filemanager.fileExists(atPath: savedVM), performSanityCheck(savedVM) {
                rootController?.addVirtualMachineFromFile(savedVM)
            } else {
                toRemove.append((savedVMs?.lastIndex(of: savedVM))!)
            }
        }

        if let controller = rootController, controller.getVirtualMachinesCount() > 0 {
            rootController?.setCurrentVirtualMachine(rootController?.virtualMachines[0])
        }

        if toRemove.count > 0 {
            var removed: [String] = []
            toRemove.reverse()
            for index in toRemove {
                removed.append((savedVMs?.remove(at: index))!)
            }

            Utils.showAlert(window: (rootController?.view.window)!, style: NSAlert.Style.informational, message: String(format: NSLocalizedString("AppDelegate.couldNotFindExistingVMs", comment: ""), removed.joined(separator: ", ")))

            let userDefaults = UserDefaults.standard
            userDefaults.set(savedVMs, forKey: MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS)
        }
    }

    fileprivate func performSanityCheck(_ filename: String) -> Bool {
        if filename.hasSuffix("." + MacMulatorConstants.VM_EXTENSION) {
            let fileManager = FileManager.default
            do {
                let fileNames: [String] = try fileManager.contentsOfDirectory(atPath: filename)
                for file in fileNames {
                    if file == MacMulatorConstants.INFO_PLIST {
                        return true
                    }
                }
            } catch {
                print(String(format: NSLocalizedString("AppDelegate.errorReading", comment: ""), filename, error.localizedDescription))
            }
        }

        return false
    }

    fileprivate func setupDefaultsPreferences(_ userDefaults: UserDefaults) {
        if userDefaults.value(forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH) == nil {
            userDefaults.set(Utils.getDefaultVmFolderPath(), forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH)
        }
        if userDefaults.value(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH) == nil {
            userDefaults.set(Utils.getDefaultQemuFolderPath(), forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)
        }
        if userDefaults.value(forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE) == nil {
            userDefaults.set(10, forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE)
        }
        if userDefaults.value(forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED) == nil {
            userDefaults.set(false, forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED)
        }
    }
}
