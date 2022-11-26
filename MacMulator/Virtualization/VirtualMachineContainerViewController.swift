//
//  VirtualMachineContainerViewController.swift
//  MacMulator
//
//  Created by Vale on 14/04/22.
//

import Cocoa
import Virtualization

@available(macOS 12.0, *)
class VirtualMachineContainerViewController : NSViewController, NSWindowDelegate {
    
    var virtualMachine: VirtualMachine?
    var recoveryMode: Bool = false
    var vmController: VirtualMachineViewController?
    var vmRunner: VirtualMachineRunner?
 
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
    }
    
    func setRecoveryMode(_ recoveryMode: Bool) {
        self.recoveryMode = recoveryMode
    }
    
    func setVmController(_ controller: VirtualMachineViewController) {
        vmController = controller;
    }
    
    func setVmRunner(_ runner: VirtualMachineRunner) {
        vmRunner = runner
    }
    
    override func viewDidAppear() {
        self.view.window?.delegate = self;
        self.view.window?.title = (virtualMachine?.displayName ?? "") + " - MacMulator"
        
        if let virtualMachine = virtualMachine {
            let resolution = Utils.getResolutionElements(virtualMachine.displayResolution);
            self.view.window?.setContentSize(CGSize(width: resolution[0], height: resolution[1]));
            self.view.window?.center()
            
            if let vmRunner = self.vmRunner {
                let runner = vmRunner as! VirtualizationFrameworkVirtualMachineRunner
                runner.setVmView(self.view as! VZVirtualMachineView);
                runner.setVmViewController(self);
                runner.runVM(recoveryMode: self.recoveryMode, uponCompletion: {
                    result, virtualMachine in
                    DispatchQueue.main.async {
                        if (result.exitCode != 0) {
                            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: "VM execution failed with error: " + result.error!);
                        }
                    }
                });
            }
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let response = Utils.showPrompt(window: self.view.window!, style: NSAlert.Style.warning, message: "Closing this window will forcibly kill the running VM.\nIt is strogly suggested to shut it down gracefully using the guest OS shut down procedure, or you might loose your unsaved work.\n\nDo you want to continue?");
        if response.rawValue != Utils.ALERT_RESP_OK {
            return false;
        } else {
            stopVM()
            return true;
        }
    }
        
    func stopVM() {
        if let vmRunner = self.vmRunner {
            if (vmRunner.isVMRunning()) {
                vmRunner.stopVM();
            }
        }
        if let virtualMachine = virtualMachine {
            vmController?.cleanupStoppedVM(virtualMachine)
        }
        self.view.window?.close();
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if (segue.identifier == MacMulatorConstants.SHOW_INSTALLING_OS_SEGUE) {
            let destinationController = segue.destinationController as! VirtualizationFrameworkInstallVMViewController;
            if let vmRunner = self.vmRunner {
                let runner = vmRunner as! VirtualizationFrameworkVirtualMachineRunner
                destinationController.setParentRunner(runner)
                destinationController.setVirtualMachine(runner.vzVirtualMachine!)
                let installDrive = Utils.findIPSWInstallDrive(runner.managedVm.drives)
                if installDrive != nil {
                    destinationController.setRestoreImageURL(URL(fileURLWithPath: installDrive!.path))
                }
            }
        }
    }
}
