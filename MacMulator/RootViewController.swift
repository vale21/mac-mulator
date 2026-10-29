//
//  Created by Vale on 26/01/21.
//

import Cocoa

class RootViewController: NSSplitViewController, NSWindowDelegate {
    private var listController: VirtualMachinesListViewController?
    private var vmController: VirtualMachineViewController?

    var currentVm: VirtualMachine?
    var virtualMachines: [VirtualMachine] = []
    var runningVMs: [VirtualMachine: VirtualMachineRunner] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        let children = children

        listController = children[0] as? VirtualMachinesListViewController
        if let listController {
            listController.setRootController(self)
        }

        vmController = children[1] as? VirtualMachineViewController
        if let vmController {
            vmController.setRootController(self)
        }

        let delegate = NSApp.delegate as! AppDelegate
        delegate.rootControllerDidFinishLoading(self)
    }

    override func viewWillAppear() {
        view.window?.delegate = self
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        if areThereRunningVMs() {
            let response = Utils.showPrompt(window: view.window!, style: NSAlert.Style.warning, message: NSLocalizedString("RootViewController.forciblyClosing", comment: ""), virtualMachine: nil)
            if response.rawValue != Utils.ALERT_RESP_OK {
                return false
            } else {
                killAllRunningVMs()
            }
        }
        return true
    }

    func startVMMenuBarClicked(_ sender: Any) {
        vmController?.startVM(sender: sender)
    }

    func startVMInRecoveryMenuBarClicked(_ sender: Any) {
        vmController?.startVMInRecovery(sender: sender)
    }

    func stopVMMenubarClicked(_ sender: Any) {
        vmController?.stopVM(sender)
    }

    func pauseVMMenuBarClicked(_ sender: Any) {
        vmController?.pauseVM(sender: sender)
    }

    func attachUSBImageToVM(_ sender: Any, _ virtualDrive: VirtualDrive) {
        vmController?.attachUSBImageToVM(sender: sender, virtualDrive: virtualDrive)
    }

    func showConsoleMenubarClicked(_: Any) {
        view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.SHOW_CONSOLE_SEGUE, sender: self)
    }

    func editVMmenuBarClicked(_ sender: Any) {
        NSApp.mainWindow?.windowController?.performSegue(withIdentifier: MacMulatorConstants.EDIT_VM_SEGUE, sender: [sender, currentVm]) // The sender here determines which tab to show
    }

    func createVMSnapshot(sender: Any) {
        vmController?.createVMSnapshot(sender: sender)
    }

    func cloneVMMenuBarClicked(_: Any) {
        if let currentVm {
            if let vmIndex = getIndex(of: currentVm) {
                cloneVirtualMachineAt(vmIndex)
            }
        }
    }

    func deleteVMMenuBarClicked(_: Any) {
        if let currentVm {
            guard canDelete(currentVm) else { return }
            if let vmIndex = getIndex(of: currentVm) {
                _ = removeVirtualMachineAt(vmIndex)
            }
            listController?.refreshList()
            if virtualMachines.isEmpty {
                setCurrentVirtualMachine(nil)
            } else {
                setCurrentVirtualMachine(virtualMachines.first)
            }
        }
    }

    func showVMInFinderMenuBarClicked(_: Any) {
        if let currentVm {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: currentVm.path, isDirectory: false)])
        }
    }

    @available(macOS 13.0, *)
    func convertToQemuMenuBarClicked(_: Any) {
        vmController?.convertToQemuMenuBarClicked(self)
    }

    @available(macOS 13.0, *)
    func convertToAppleMenuBarClicked(_: Any) {
        vmController?.convertToAppleMenuBarClicked(self)
    }

    @available(macOS 13.0, *)
    func convertToTemplateMenuBarClicked(_: Any) {
        if let currentVm {
            if let vmIndex = getIndex(of: currentVm) {
                convertVirtualMachineToTemplateAt(vmIndex)
            }
        }
    }

    func setCurrentVirtualMachine(_ currentVm: VirtualMachine?) {
        if let vm = currentVm {
            Utils.removeUnexistingDrives(vm)
            vmController?.setVirtualMachine(vm)
            let index = virtualMachines.firstIndex(of: vm) ?? -1
            listController?.selectElement(index)
            listController?.setState(index, vm)
        } else {
            vmController?.setVirtualMachine(nil)
            listController?.selectElement(-1)
        }

        self.currentVm = currentVm

        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.refreshVMMenus()
    }

    func startupCompleted() {
        if virtualMachines.isEmpty {
            vmController?.setVirtualMachine(nil)
        }
    }

    func addVirtualMachineFromFile(_ fileName: String) {
        let virtualMachine = VirtualMachine.readFromPlist(fileName, MacMulatorConstants.INFO_PLIST)
        if let vm = virtualMachine {
            addVirtualMachine(vm)
            if #available(macOS 13.0, *) {
                if vm.type == MacMulatorConstants.APPLE_VM, vm.os == QemuConstants.OS_LINUX, !vm.hasLinkedDrives, Utils.hostArchitecture() != Utils.getMachineArchitecture(vm.architecture) {
                    vmController?.convertToQemuMenuBarClicked(self)
                }
            }
        }
    }

    func addVirtualMachine(_ virtualMachine: VirtualMachine) {
        if !virtualMachines.contains(virtualMachine) {
            virtualMachines.append(virtualMachine)
            listController?.refreshList()
        }

        setCurrentVirtualMachine(virtualMachine)

        let delegate = NSApp.delegate as! AppDelegate
        delegate.addSavedVM(virtualMachine.path)
    }

    func getVirtualMachinesCount() -> Int {
        virtualMachines.count
    }

    func getVirtualMachineAt(_ index: Int) -> VirtualMachine {
        virtualMachines[index]
    }

    func getVirtualMachine(name: String) -> VirtualMachine? {
        for virtualMachine in virtualMachines {
            if virtualMachine.displayName == name {
                return virtualMachine
            }
        }
        return nil
    }

    func getIndex(of virtualMachine: VirtualMachine) -> Int? {
        virtualMachines.firstIndex(of: virtualMachine)
    }

    func moveVm(at originalRow: Int, to newRow: Int) {
        let vm = virtualMachines.remove(at: originalRow)
        virtualMachines.insert(vm, at: newRow)

        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.moveSavedVm(at: originalRow, to: newRow)
    }

    func refreshViewForVM(_ virtualMachine: VirtualMachine?) {
        listController?.refreshList()
        vmController?.setVirtualMachine(virtualMachine)
    }

    /// Renames the folder of a VM after its (possibly changed) name, adding a " (2)", " (3)", ... suffix if it is already taken.
    /// Drives, snapshots and the linked clones depending on the VM are updated accordingly.
    func renameVMFolderToMatchName(_ vm: VirtualMachine) {
        guard !isVMRunning(vm) else { return }
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let name = vm.displayName.components(separatedBy: invalidCharacters).joined(separator: "-").trimmingCharacters(in: .whitespaces)
        let oldPath = vm.path
        guard !name.isEmpty, URL(fileURLWithPath: oldPath).deletingPathExtension().lastPathComponent != name else { return }

        let fileManager = FileManager.default
        var newPath = Utils.computeVMPath(vmName: name)
        var counter = 2
        while fileManager.fileExists(atPath: newPath) {
            newPath = Utils.computeVMPath(vmName: "\(name) (\(counter))")
            counter += 1
        }

        do {
            try fileManager.moveItem(atPath: oldPath, toPath: newPath)
        } catch {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("RootViewController.renameFailed", comment: ""), "\(error.localizedDescription)"), virtualMachine: vm)
            return
        }

        VirtualMachine.setupPaths(vm, newPath)
        vm.writeToPlist()
        SandboxBookmarks.remember(URL(fileURLWithPath: newPath))
        (NSApp.delegate as? AppDelegate)?.replaceSavedVM(oldPath, with: newPath)

        // Linked clones refer to the drives of their template by absolute path.
        let oldPrefix = oldPath + "/"
        for other in virtualMachines where other !== vm {
            var changed = false
            for drive in other.drives {
                if let backingPath = drive.backingPath, backingPath.hasPrefix(oldPrefix) {
                    drive.backingPath = newPath + "/" + backingPath.dropFirst(oldPrefix.count)
                    changed = true
                }
            }
            if changed {
                other.writeToPlist()
            }
        }
        refreshViewForVM(vm)
    }

    /// VMs whose drives are linked to a drive of the given template.
    func linkedClones(of template: VirtualMachine) -> [VirtualMachine] {
        let templatePrefix = template.path + "/"
        return virtualMachines.filter { vm in
            vm !== template && vm.drives.contains(where: { $0.backingPath?.hasPrefix(templatePrefix) == true })
        }
    }

    /// A template that still has linked clones cannot be deleted: its disks are the backing files of the clones' ones.
    /// Shows an alert and returns false in that case.
    func canDelete(_ vm: VirtualMachine) -> Bool {
        guard Utils.isVMTemplate(vm) else { return true }
        let clones = linkedClones(of: vm)
        if clones.isEmpty {
            return true
        }
        Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("RootViewController.templateHasLinkedClones", comment: ""), vm.displayName, clones.map { "- " + $0.displayName }.joined(separator: "\n")), virtualMachine: vm)
        return false
    }

    func removeVirtualMachineAt(_ index: Int) -> VirtualMachine {
        if index > 0 {
            setCurrentVirtualMachine(virtualMachines[index - 1])
        } else if virtualMachines.count > 1 {
            setCurrentVirtualMachine(virtualMachines[0])
        } else {
            setCurrentVirtualMachine(nil)
        }

        let virtualMachine = virtualMachines.remove(at: index)
        if isVMRunning(virtualMachine) {
            let runner = runningVMs[virtualMachine]
            runner?.stopVM(guestStopped: false)
            runningVMs.removeValue(forKey: virtualMachine)
        }

        let delegate = NSApp.delegate as! AppDelegate
        delegate.removeSavedVM(virtualMachine.path)
        virtualMachine.cleanup()

        return virtualMachine
    }

    /// Name for a new clone, with a " (2)", " (3)", ... suffix if a VM or a folder with the same name already exists.
    private func cloneName(of name: String, linked: Bool) -> String {
        let baseName = String(format: NSLocalizedString(linked ? "RootViewController.linkedCloneOf" : "RootViewController.fullCloneOf", comment: ""), name)
        var candidate = baseName
        var counter = 2
        while virtualMachines.contains(where: { $0.displayName == candidate }) || FileManager.default.fileExists(atPath: Utils.computeVMPath(vmName: candidate)) {
            candidate = "\(baseName) (\(counter))"
            counter += 1
        }
        return candidate
    }

    func performFullClone(_ vmToClone: VirtualMachine) {
        let uniqueName = cloneName(of: vmToClone.displayName, linked: false)
        let newVMPath = Utils.computeVMPath(vmName: uniqueName)
        let shell = Shell()
        shell.runCommand("cp -c -R " + Utils.escape(vmToClone.path) + " " + Utils.escape(newVMPath), NSHomeDirectory(), uponCompletion: { _, _ in
            self.registerClone(at: newVMPath, displayName: uniqueName)
        })
    }

    /// Creates a clone whose disks are overlay layers (QCOW2 backing files or stacked ASIF images) on top of the template ones,
    /// so that it takes almost no space and is created instantly.
    func performLinkedClone(_ vmToClone: VirtualMachine) {
        let uniqueName = cloneName(of: vmToClone.displayName, linked: true)
        let newVMPath = Utils.computeVMPath(vmName: uniqueName)
        let templateDisks = vmToClone.drives.filter { $0.mediaType == QemuConstants.MEDIATYPE_DISK || $0.mediaType == QemuConstants.MEDIATYPE_NVME }

        // Overlays can only be stacked on top of sparse images, which is guaranteed by the template conversion.
        guard !templateDisks.isEmpty, templateDisks.allSatisfy({ $0.format == QemuConstants.FORMAT_QCOW2 || $0.format == QemuConstants.FORMAT_ASIF }) else {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("RootViewController.linkedCloneFailed", comment: ""), NSLocalizedString("RootViewController.linkedCloneUnsupportedDrives", comment: "")), virtualMachine: vmToClone)
            return
        }

        let fileManager = FileManager.default
        let templateDiskPaths = Set(templateDisks.map(\.path))
        do {
            // Copy everything but the disks, which are replaced by the overlays.
            try fileManager.createDirectory(atPath: newVMPath, withIntermediateDirectories: true)
            for item in try fileManager.contentsOfDirectory(atPath: vmToClone.path) {
                let sourcePath = vmToClone.path + "/" + item
                if !templateDiskPaths.contains(sourcePath) {
                    try fileManager.copyItem(atPath: sourcePath, toPath: newVMPath + "/" + item)
                }
            }
        } catch {
            try? fileManager.removeItem(atPath: newVMPath)
            Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("RootViewController.linkedCloneFailed", comment: ""), "\(error)"), virtualMachine: vmToClone)
            return
        }

        let diskImageManager = DiskImageManagerFactory().create(isVirtualizationFrameworkInUse: vmToClone.type == MacMulatorConstants.APPLE_TEMPLATE_VM)
        let overlays = templateDisks.map { templateDisk -> VirtualDrive in
            let overlay = templateDisk.clone()
            overlay.path = newVMPath + "/" + templateDisk.name + "." + MacMulatorConstants.DISK_EXTENSION
            overlay.backingPath = templateDisk.path
            return overlay
        }

        func createOverlay(at index: Int) {
            guard index < overlays.count else {
                registerClone(at: newVMPath, displayName: uniqueName, linkedDrives: overlays)
                return
            }
            diskImageManager.createLinkedDiskImage(overlays[index], backingDrive: templateDisks[index], newVMPath, uponCompletion: { errorCode, errorMessage in
                guard errorCode == 0 else {
                    try? fileManager.removeItem(atPath: newVMPath)
                    DispatchQueue.main.async {
                        Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("RootViewController.linkedCloneFailed", comment: ""), errorMessage ?? ""), virtualMachine: vmToClone)
                    }
                    return
                }
                createOverlay(at: index + 1)
            })
        }
        createOverlay(at: 0)
    }

    private func registerClone(at newVMPath: String, displayName: String, linkedDrives: [VirtualDrive] = []) {
        let temp = VirtualMachine.readFromPlist(newVMPath, "Info.plist")
        if let tempVm = temp {
            tempVm.assignNewIdForClone()
            tempVm.displayName = displayName
            if tempVm.type == MacMulatorConstants.APPLE_TEMPLATE_VM {
                tempVm.type = MacMulatorConstants.APPLE_VM
            }
            if tempVm.type == MacMulatorConstants.QEMU_TEMPLATE_VM {
                tempVm.type = MacMulatorConstants.QEMU_VM
            }

            for linkedDrive in linkedDrives {
                tempVm.drives.first(where: { $0.path == linkedDrive.path })?.backingPath = linkedDrive.backingPath
            }

            if let provisioningInformation = tempVm.provisioningInformation {
                // The cloned plist points at the original's Keychain item; give the clone its own.
                let password = provisioningInformation.userPassword
                provisioningInformation.passwordKeychainId = UUID().uuidString
                provisioningInformation.userPassword = password
            }
            tempVm.writeToPlist()
            DispatchQueue.main.async {
                self.addVirtualMachineFromFile(newVMPath)
            }
        }
    }

    func convertToFullCloneMenuBarClicked(_: Any) {
        if let currentVm, let vmIndex = getIndex(of: currentVm) {
            convertToFullCloneAt(vmIndex)
        }
    }

    /// Merges the drives of a linked clone with the template ones, so that the VM no longer depends on the template.
    func convertToFullCloneAt(_ index: Int) {
        let vm = virtualMachines[index]
        guard vm.hasLinkedDrives, Utils.isFullCloneConversionSupported(vm), !isVMRunning(vm) else { return }
        let response = Utils.showPrompt(window: view.window!, style: NSAlert.Style.warning, message: NSLocalizedString("RootViewController.convertToFullClone", comment: ""), virtualMachine: vm)
        guard response.rawValue == Utils.ALERT_RESP_OK else { return }

        if #available(macOS 13.0, *) {
            vmController?.convertToFullClone(vm)
        }
    }

    func cloneVirtualMachineAt(_ index: Int) {
        let vmToClone = virtualMachines[index]
        if Utils.isVMTemplate(vmToClone) {
            vmController?.cloneVirtualMachine(vmToClone)
        } else {
            performFullClone(vmToClone)
        }
    }

    @available(macOS 13.0, *)
    func convertVirtualMachineToTemplateAt(_ index: Int) {
        let vmToConvert = virtualMachines[index]
        let rawVMDrives = Utils.findRawDrives(vmToConvert.drives)
        let removableVMDrives = Utils.findExternalDrives(vmToConvert.drives)
        var promptText = NSLocalizedString("RootViewController.convertToTemplate", comment: "") + "\n\n"
        if !rawVMDrives.isEmpty {
            let targetFormat = vmToConvert.type == MacMulatorConstants.QEMU_VM ? "QCOW2" : "ASIF"
            promptText += String(format: NSLocalizedString("RootViewController.convertToTemplateRawDrives", comment: ""), targetFormat, rawVMDrives.map { "- " + $0.name }.joined(separator: "\n")) + "\n\n"
        }
        if !removableVMDrives.isEmpty {
            promptText += String(format: NSLocalizedString("RootViewController.convertToTemplateRemovableDrives", comment: ""), removableVMDrives.map { "- " + $0.name }.joined(separator: "\n")) + "\n\n"
        }
        promptText += NSLocalizedString("RootViewController.convertToTemplateConfirm", comment: "")
        let response = Utils.showPrompt(window: view.window!, style: NSAlert.Style.warning, message: promptText, virtualMachine: vmToConvert)
        if response.rawValue == Utils.ALERT_RESP_OK {
            vmController?.convertToTemplateMenuBarClicked(self)
        }
    }

    func setRunningVM(_ vm: VirtualMachine, _ runner: VirtualMachineRunner) {
        runningVMs[vm] = runner

        listController?.setState(virtualMachines.firstIndex(of: vm)!, .running)

        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.refreshVMMenus()
    }

    func unsetRunningVM(_ vm: VirtualMachine) {
        runningVMs.removeValue(forKey: vm)
        let index = virtualMachines.firstIndex(of: vm)
        if let idx = index {
            listController?.setState(idx, isVMPaused(vm) ? .paused : .stopped)
        }

        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.refreshVMMenus()
    }

    func isCurrentVMRunning() -> Bool {
        isVMRunning(currentVm)
    }

    func isVMRunning(_ vm: VirtualMachine?) -> Bool {
        vm != nil && runningVMs[vm!] != nil
    }

    func isVMPaused(_ vm: VirtualMachine?) -> Bool {
        if let vm {
            if #available(macOS 14.0, *), vm.type == MacMulatorConstants.APPLE_VM {
                let filemanager = FileManager.default
                if filemanager.fileExists(atPath: vm.path + "/" + MacMulatorConstants.SAVE_FILE_NAME) {
                    return true
                } else {
                    return false
                }
            }
        }
        return false
    }

    func getRunnerForRunningVM(_ vm: VirtualMachine) -> VirtualMachineRunner? {
        runningVMs[vm]
    }

    func getRunnerForCurrentVM() -> VirtualMachineRunner? {
        if let currentVm {
            return runningVMs[currentVm]
        }
        return nil
    }

    func areThereRunningVMs() -> Bool {
        runningVMs.count > 0
    }

    func killAllRunningVMs() {
        for runner in runningVMs.values {
            runner.stopVM(guestStopped: false)
        }
    }
}
