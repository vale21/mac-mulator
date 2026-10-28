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
                if vm.type == MacMulatorConstants.APPLE_VM, vm.os == QemuConstants.OS_LINUX, Utils.hostArchitecture() != Utils.getMachineArchitecture(vm.architecture) {
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

    fileprivate func performFullClone(_ vmToClone: VirtualMachine) {
        let newVMPath = Utils.computeVMPath(vmName: String(format: NSLocalizedString("RootViewController.cloneOf", comment: ""), vmToClone.displayName))
        let shell = Shell()
        shell.runCommand("cp -c -R " + Utils.escape(vmToClone.path) + " " + Utils.escape(newVMPath), NSHomeDirectory(), uponCompletion: { _, _ in
            let temp = VirtualMachine.readFromPlist(newVMPath, "Info.plist")
            if let tempVm = temp {
                tempVm.displayName = String(format: NSLocalizedString("RootViewController.cloneOf", comment: ""), tempVm.displayName)
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
        })
    }

    func cloneVirtualMachineAt(_ index: Int) {
        let vmToClone = virtualMachines[index]
        if Utils.isVMTemplate(vmToClone) {
            vmController?.performSegue(withIdentifier: MacMulatorConstants.SHOW_CLONE_VIEW_SEGUE, sender: self)
        } else {
            performFullClone(vmToClone)
        }
    }

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
            if vmToConvert.type == MacMulatorConstants.APPLE_VM, #available(macOS 27.0, *) {
                vmToConvert.type = MacMulatorConstants.APPLE_TEMPLATE_VM
            } else if vmToConvert.type == MacMulatorConstants.QEMU_VM {
                vmToConvert.type = MacMulatorConstants.QEMU_TEMPLATE_VM
            }
            setCurrentVirtualMachine(vmToConvert)
            vmToConvert.writeToPlist()
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
