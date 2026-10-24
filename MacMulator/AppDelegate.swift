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
    private(set) var rootController: RootViewController?
    private var fileName: String?
    private var initialized = false

    @IBOutlet var preferencesMenuItem: NSMenuItem!
    @IBOutlet var preferencesSeparator: NSMenuItem!
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
    @IBOutlet var usbAttachImageMenuItem: NSMenuItem!
    @IBOutlet var usbConfigureMenuItem: NSMenuItem!
    @IBOutlet var snapshotsMenuItem: NSMenuItem!
    @IBOutlet var snapshotCreateMenuItem: NSMenuItem!
    @IBOutlet var snapshotsViewRestoreMenuItem: NSMenuItem!
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
                        Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.informational, message: String(format: NSLocalizedString("EditVMViewControllerHardware.imageAlreadyLoaded", comment: ""), path), virtualMachine: nil)
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

    private static let usbPassthroughMenuTag = 2701

    @available(macOS 27.0, *)
    @IBAction func toggleUSBPassthroughMenuBarClicked(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let key = info["key"] as? String,
              let virtualMachine = rootController?.currentVm else { return }
        let registryID = (info["id"] as? NSNumber)?.uint64Value

        var saved = virtualMachine.usbPassthroughDevices ?? []
        var names = virtualMachine.usbPassthroughDeviceNames ?? [:]
        let runner = rootController?.isVMRunning(virtualMachine) == true ? rootController?.getRunnerForRunningVM(virtualMachine) as? VirtualizationFrameworkVirtualMachineRunner : nil
        if sender.state == .on {
            if let index = saved.firstIndex(of: key) {
                saved.remove(at: index)
            }
            if let registryID, runner?.isPassthroughAttached(registryID: registryID) == true {
                runner?.detachPassthroughDevice(registryID: registryID)
            }
        } else {
            saved.append(key)
            if let name = info["name"] as? String {
                names[key] = name
            }
            if let registryID, let runner, otherVMUsingPassthroughDevice(registryID, excluding: virtualMachine) == nil {
                runner.attachPassthroughDevice(registryID: registryID)
            }
        }
        names = names.filter { saved.contains($0.key) }
        virtualMachine.usbPassthroughDevices = saved
        virtualMachine.usbPassthroughDeviceNames = names
        virtualMachine.writeToPlist()
        refreshUSBPassthroughMenu()
    }

    @available(macOS 27.0, *)
    private func otherVMUsingPassthroughDevice(_ registryID: UInt64, excluding current: VirtualMachine) -> VirtualMachine? {
        guard let running = rootController?.runningVMs else { return nil }
        for (vm, runner) in running where vm != current {
            if let vfRunner = runner as? VirtualizationFrameworkVirtualMachineRunner, vfRunner.isPassthroughAttached(registryID: registryID) {
                return vm
            }
        }
        return nil
    }

    func refreshUSBPassthroughMenu() {
        #if arch(arm64)
            guard let submenu = usbDevicesMenuItem?.submenu else { return }
            submenu.autoenablesItems = false
            for item in submenu.items where item.tag == AppDelegate.usbPassthroughMenuTag {
                submenu.removeItem(item)
            }

            guard let virtualMachine = rootController?.currentVm, virtualMachine.type == MacMulatorConstants.APPLE_VM else { return }

            var newItems: [NSMenuItem] = []
            if #available(macOS 27.0, *) {
                UsbPassthroughManager.shared.start()
                let runner = rootController?.isVMRunning(virtualMachine) == true ? rootController?.getRunnerForRunningVM(virtualMachine) as? VirtualizationFrameworkVirtualMachineRunner : nil

                let candidates = UsbPassthroughManager.shared.candidates()
                var autoAttachCounts: [String: Int] = [:]
                for key in virtualMachine.usbPassthroughDevices ?? [] {
                    autoAttachCounts[key, default: 0] += 1
                }

                if candidates.isEmpty, autoAttachCounts.isEmpty {
                    let emptyTitle = UsbPassthroughManager.shared.lastError ?? NSLocalizedString("AppDelegate.noUsbDevices", comment: "")
                    let emptyItem = NSMenuItem(title: emptyTitle, action: nil, keyEquivalent: "")
                    emptyItem.isEnabled = false
                    newItems.append(emptyItem)
                }
                var names = virtualMachine.usbPassthroughDeviceNames ?? [:]
                var namesChanged = false
                for candidate in candidates where autoAttachCounts[candidate.key] != nil && names[candidate.key] != candidate.name {
                    names[candidate.key] = candidate.name
                    namesChanged = true
                }
                if namesChanged {
                    virtualMachine.usbPassthroughDeviceNames = names
                    virtualMachine.writeToPlist()
                }
                for candidate in candidates {
                    let item = NSMenuItem(title: candidate.name, action: #selector(toggleUSBPassthroughMenuBarClicked(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = ["key": candidate.key, "id": NSNumber(value: candidate.registryID), "name": candidate.name] as [String: Any]
                    item.isEnabled = true
                    if let count = autoAttachCounts[candidate.key], count > 0 {
                        autoAttachCounts[candidate.key] = count - 1
                        item.state = .on
                    }
                    if runner?.isPassthroughAttached(registryID: candidate.registryID) != true, let holder = otherVMUsingPassthroughDevice(candidate.registryID, excluding: virtualMachine) {
                        item.title = String(format: NSLocalizedString("AppDelegate.deviceInUse", comment: ""), candidate.name, holder.displayName)
                        item.isEnabled = false
                        item.state = .off
                    }
                    newItems.append(item)
                }
                for (key, count) in autoAttachCounts.sorted(by: { $0.key < $1.key }) where count > 0 {
                    for _ in 0 ..< count {
                        let item = NSMenuItem(title: String(format: NSLocalizedString("AppDelegate.deviceNotConnected", comment: ""), names[key] ?? key), action: nil, keyEquivalent: "")
                        item.isEnabled = false
                        item.state = .on
                        newItems.append(item)
                    }
                }
            } else {
                return
            }

            newItems.append(NSMenuItem.separator())
            for (index, item) in newItems.enumerated() {
                item.tag = AppDelegate.usbPassthroughMenuTag
                submenu.insertItem(item, at: index)
            }
        #endif
    }

    @IBAction func createNewSnapshotMenuBarClicked(_: Any) {
        rootController?.createVMSnapshot(sender: self)
    }

    @IBAction func viewRestoreSnapshotMenuBarClicked(_: Any) {}

    @IBAction func exportVMToParallelsMenuBarClicked(_: Any) {
        if #available(macOS 11.0, *) {
            Utils.showDirectorySelector(uponSelection: { panel in
                if let vm = rootController?.currentVm {
                    do {
                        try ImportExportHerlper.exportVmToParallels(vm: vm, destinationPath: panel.url!.path)
                        Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.informational, message: NSLocalizedString("AppDelegate.exportToParallelsComplete", comment: ""), virtualMachine: vm)
                    } catch {
                        Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("AppDelegate.exportFailed", comment: ""), error.localizedDescription), virtualMachine: vm)
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
                    Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("AppDelegate.importFailed", comment: ""), error.localizedDescription), virtualMachine: nil)
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
        var tabIdentifier = "general"
        if sender as? NSMenuItem == usbConfigureMenuItem {
            tabIdentifier = "hardware"
        } else if sender as? NSMenuItem == snapshotsViewRestoreMenuItem {
            tabIdentifier = "snapshots"
        }

        rootController?.editVMmenuBarClicked(tabIdentifier) // The sender here determines which tab to show
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
        defer { refreshUSBPassthroughMenu() }
        vmMenu.autoenablesItems = false
        #if APPSTORE
            preferencesMenuItem.isHidden = true
            preferencesSeparator.isHidden = true
        #endif

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
                snapshotsMenuItem.isEnabled = false
                snapshotCreateMenuItem.isEnabled = false
                snapshotsViewRestoreMenuItem.isEnabled = false
                usbDevicesMenuItem.isEnabled = false
                showConsoleOutputmenuItem.isEnabled = false
            } else {
                if let vm = rootController.currentVm {
                    cloneVMMemuItem.isEnabled = true
                    showVMInFinderMenuItem.isEnabled = true
                    settingsMenuItem.isEnabled = true
                    snapshotsMenuItem.isEnabled = true
                    snapshotCreateMenuItem.isEnabled = true
                    snapshotsViewRestoreMenuItem.isEnabled = true

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
                                    usbDevicesMenuItem.submenu?.insertItem(detachMenuItem, at: usbDevicesMenuItem.submenu!.index(of: usbAttachImageMenuItem) + 1)
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
                                if let detachItem = usbDevicesMenuItem.submenu!.items.first(where: { item in item.title == NSLocalizedString("AppDelegate.detachImage", comment: "") }) {
                                    usbDevicesMenuItem.submenu?.removeItem(detachItem)
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
        // Opened from the Finder or an open panel: keep the access to it across launches.
        SandboxBookmarks.remember(URL(fileURLWithPath: filename))
        if performSanityCheck(filename) {
            if initialized {
                rootController?.addVirtualMachineFromFile(filename)
            } else {
                fileName = filename
            }
            return true
        } else {
            Utils.showAlert(window: sender.mainWindow!, style: NSAlert.Style.warning, message: String(format: NSLocalizedString("AppDelegate.cannotOpenFile", comment: ""), filename), virtualMachine: nil)
            return false
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        if #available(macOS 27.0, *) {
            #if arch(arm64)
                NotificationCenter.default.addObserver(forName: UsbPassthroughManager.didConnectNotification, object: nil, queue: .main) { [weak self] _ in
                    for runner in self?.rootController?.runningVMs.values ?? [:].values {
                        (runner as? VirtualizationFrameworkVirtualMachineRunner)?.restoreSavedPassthroughDevices()
                    }
                }
                NotificationCenter.default.addObserver(forName: UsbPassthroughManager.didRemoveNotification, object: nil, queue: .main) { [weak self] notification in
                    if let registryID = (notification.userInfo?["registryID"] as? NSNumber)?.uint64Value {
                        for runner in self?.rootController?.runningVMs.values ?? [:].values {
                            (runner as? VirtualizationFrameworkVirtualMachineRunner)?.passthroughAccessoryRemoved(registryID: registryID)
                        }
                    }
                }
                NotificationCenter.default.addObserver(forName: UsbPassthroughManager.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                    self?.refreshUSBPassthroughMenu()
                }
            #endif
        }
        let userDefaults = UserDefaults.standard

        // Before touching any VM file: regain access to the folders and files the user picked (App Store flavor).
        SandboxBookmarks.restoreAll()
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

        let qemuPath = QemuUtils.getQemuPath()

        DispatchQueue.global().async {
            // Update the QEMU capabilities cache for the current QEMU path and all the VMs, so that the UI can be responsive when the user tries to edit a VM.
            _ = QemuCapabilitiesReporter.getInstance(forQemuPath: qemuPath)
            if let rootController = self.rootController {
                for vm in rootController.virtualMachines {
                    _ = QemuCapabilitiesReporter.getInstance(forQemuPath: QemuUtils.getQemuPath(for: vm))
                }
            }
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

            Utils.showAlert(window: (rootController?.view.window)!, style: NSAlert.Style.informational, message: String(format: NSLocalizedString("AppDelegate.couldNotFindExistingVMs", comment: ""), removed.joined(separator: ", ")), virtualMachine: nil)

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
