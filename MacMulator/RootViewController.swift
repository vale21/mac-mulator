//
//  ViewController.swift
//  QManage
//
//  Created by Vale on 26/01/21.
//

import Cocoa

class RootViewController: NSSplitViewController, NSWindowDelegate {

  
    private var listController: VirtualMachinesListViewController?;
    private var vmController: VirtualMachineViewController?;
    
    var currentVm: VirtualMachine?
    var virtualMachines: [VirtualMachine] = []
    var runningVMs: [VirtualMachine : VirtualMachineRunner] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad();
            
        let children = self.children;
        
        listController = children[0] as? VirtualMachinesListViewController;
        if let listController = self.listController {
            listController.setRootController(self);
        }
        
        vmController = children[1] as? VirtualMachineViewController;
        if let vmController = self.vmController {
            vmController.setRootController(self);
        }
        
        let delegate = NSApp.delegate as! AppDelegate;
        delegate.rootControllerDidFinishLoading(self);
    }
    
    override func viewWillAppear() {
        self.view.window?.delegate = self;
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if areThereRunningVMs() {
            let response = Utils.showPrompt(window: self.view.window!, style: NSAlert.Style.warning, message: "You have running VMs.\nClosing MacMulator will forcibly kill any running VM.\nIt is strogly suggested to shut them down gracefully using the guest OS shut down procedure, or you might loose your unsaved work.\n\nDo you want to continue?");
            if response.rawValue != Utils.ALERT_RESP_OK {
                return false;
            } else {
                killAllRunningVMs();
            }
        }
        return true;
    }

    func startVMMenuBarClicked(_ sender: Any) {
        vmController?.startVM(sender: sender);
    }
    
    func startVMInRecoveryMenuBarClicked(_ sender: Any) {
        vmController?.startVMInRecovery(sender: sender);
    }
    
    func stopVMMenubarClicked(_ sender: Any) {
        vmController?.stopVM(sender)
    }
    
    func pauseVMMenuBarClicked(_ sender: Any) {
        vmController?.pauseVM(sender: sender)
    }
    
    func attachUSBImageToVM(_ sender: Any, _ path: String) {
        vmController?.attachUSBImageToVM(sender: sender, path: path)
    }
    
    func showConsoleMenubarClicked(_ sender: Any) {
        self.view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.SHOW_CONSOLE_SEGUE, sender: self);
    }
    
    func editVMmenuBarClicked(_ sender: Any) {
        NSApp.mainWindow?.windowController?.performSegue(withIdentifier: MacMulatorConstants.EDIT_VM_SEGUE, sender: currentVm);
    }
    
    @IBAction func cloneVMMenuBarClicked(_ sender: Any) {
        if let currentVm = self.currentVm {
            if let vmIndex = getIndex(of: currentVm) {
                self.cloneVirtualMachineAt(vmIndex)
            }
        }
    }
    
    @IBAction func showVMInFinderMenuBarClicked(_ sender: Any) {
        if let currentVm = self.currentVm {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: currentVm.path, isDirectory: false)])
        }
    }
    
    @available(macOS 13.0, *)
    func convertToQemuMenuBarClicked(_ sender: Any) {
        if let currentVm = self.currentVm {
            QemuUtils.createAuxiliaryDriveFilesOnDisk(currentVm)
            VirtualizationFrameworkLinuxSupport.deleteLinuxVirtualMachineData(vm: currentVm)
            currentVm.type = MacMulatorConstants.QEMU_VM
            currentVm.writeToPlist()
            vmController?.setVirtualMachine(currentVm)
            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.informational, message: "The VM was successfully converted to QEMU format.")
        }
    }
    
    @available(macOS 13.0, *)
    func convertToAppleMenuBarClicked(_ sender: Any) {
        if let currentVm = self.currentVm {
            VirtualizationFrameworkLinuxSupport.createLinuxVirtualMachineData(vm: currentVm)
            QemuUtils.deleteAuxiliaryDriveFilesOnDisk(currentVm)
            currentVm.type = MacMulatorConstants.APPLE_VM
            currentVm.writeToPlist()
            vmController?.setVirtualMachine(currentVm)
            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.informational, message: "The VM was successfully converted to Apple format.")
        }
    }
    
    func setCurrentVirtualMachine(_ currentVm: VirtualMachine?) {
        if let vm = currentVm {
            Utils.removeUnexistingDrives(vm)
            vmController?.setVirtualMachine(vm);
            listController?.selectElement(virtualMachines.firstIndex(of: vm) ?? -1);
        } else {
            vmController?.setVirtualMachine(nil);
            listController?.selectElement(-1);
        }
        
        self.currentVm = currentVm;
        
        let appDelegate = NSApp.delegate as! AppDelegate;
        appDelegate.refreshVMMenus()
    }
    
    func addVirtualMachineFromFile(_ fileName: String) {
        let virtualMachine = VirtualMachine.readFromPlist(fileName, MacMulatorConstants.INFO_PLIST);
        if let vm = virtualMachine {
            self.addVirtualMachine(vm);
        }
    }
    
    func addVirtualMachine(_ virtualMachine: VirtualMachine) {
        if (!virtualMachines.contains(virtualMachine)) {
            virtualMachines.append(virtualMachine);
            listController?.refreshList();
        }
        
        self.setCurrentVirtualMachine(virtualMachine);
        
        let delegate = NSApp.delegate as! AppDelegate;
        delegate.addSavedVM(virtualMachine.path);
    }
    
    func getVirtualMachinesCount() -> Int {
        return virtualMachines.count;
    }
    
    func getVirtualMachineAt(_ index: Int) -> VirtualMachine {
        return virtualMachines[index];
    }
    
    func getVirtualMachine(name: String) -> VirtualMachine? {
        for virtualMachine in virtualMachines {
            if virtualMachine.displayName == name {
                return virtualMachine;
            }
        }
        return nil;
    }
    
    func getIndex(of virtualMachine: VirtualMachine) -> Int? {
        return virtualMachines.firstIndex(of: virtualMachine);
    }
    
    func moveVm(at originalRow: Int, to newRow: Int) {
        let vm = virtualMachines.remove(at: originalRow);
        virtualMachines.insert(vm, at: newRow);
        
        let appDelegate = NSApp.delegate as! AppDelegate;
        appDelegate.moveSavedVm(at: originalRow, to: newRow);
    }
    
    func refreshViewForVM(_ virtualMachine: VirtualMachine?) {
        self.listController?.refreshList();
        self.vmController?.setVirtualMachine(virtualMachine);
    }
    
    
    func removeVirtualMachineAt(_ index: Int) -> VirtualMachine {
        if index > 0 {
            self.setCurrentVirtualMachine(virtualMachines[index - 1]);
        } else if virtualMachines.count > 1 {
            self.setCurrentVirtualMachine(virtualMachines[0]);
        } else {
            self.setCurrentVirtualMachine(nil);
        }
        
        let virtualMachine = virtualMachines.remove(at: index);
        if self.isVMRunning(virtualMachine) {
            let runner = self.runningVMs[virtualMachine];
            runner?.stopVM(guestStopped: false)
            self.runningVMs.removeValue(forKey: virtualMachine);
        }
        
        let delegate = NSApp.delegate as! AppDelegate;
        delegate.removeSavedVM(virtualMachine.path);
        
        return virtualMachine;
    }
    
    func cloneVirtualMachineAt(_ index: Int) {
        let vmToClone = virtualMachines[index];
        let newVMPath = Utils.computeVMPath(vmName: "Clone of " + vmToClone.displayName)
        let shell = Shell();
        shell.runCommand("cp -c -R " + Utils.escape(vmToClone.path) + " " + Utils.escape(newVMPath), NSHomeDirectory(), uponCompletion: { terminationCode in
            let temp = VirtualMachine.readFromPlist(newVMPath, "Info.plist");
            if let tempVm = temp {
                tempVm.displayName = "Clone of " + tempVm.displayName;
                tempVm.writeToPlist();
                DispatchQueue.main.async {
                    self.addVirtualMachineFromFile(newVMPath);
                }
            }
        })
    }
    
    func setRunningVM(_ vm: VirtualMachine, _ runner: VirtualMachineRunner) {
        runningVMs[vm] = runner
        
        listController?.setRunning(virtualMachines.firstIndex(of: vm)!, true)
        
        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.refreshVMMenus()
    }
    
    func unsetRunningVM(_ vm: VirtualMachine) {
        runningVMs.removeValue(forKey: vm)
        let index = virtualMachines.firstIndex(of: vm)
        if let idx = index {
            listController?.setRunning(idx, false)
        }
        
        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.refreshVMMenus()
    }

    func isCurrentVMRunning() -> Bool {
        return isVMRunning(currentVm)
    }
    
    func isVMRunning(_ vm: VirtualMachine?) -> Bool {
        return vm != nil && runningVMs[vm!] != nil
    }
    
    func isVMPaused(_ vm: VirtualMachine?) -> Bool {
        if let vm = vm {
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
        return runningVMs[vm];
    }
    
    func getRunnerForCurrentVM() -> VirtualMachineRunner? {
        if let currentVm = self.currentVm {
            return runningVMs[currentVm];
        }
        return nil;
    }
    
    func areThereRunningVMs() -> Bool {
        return runningVMs.count > 0;
    }
    
    func killAllRunningVMs() {
        for runner in runningVMs.values {
            runner.stopVM(guestStopped: false)
        }
    }

}

