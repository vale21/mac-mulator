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
    var isFullScreen = false
 
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
        self.view.window?.minSize = NSSize(width: 800, height: 600)
        
        if let virtualMachine = virtualMachine {
            let resolution = Utils.getResolutionElements(virtualMachine.displayResolution)
            var origin:[String] = []
            if let displayOrigin = virtualMachine.displayOrigin {
                origin = Utils.getOriginElements(displayOrigin)
            }
            self.view.window?.setContentSize(CGSize(width: resolution[0], height: resolution[1]));
            
            if origin.isEmpty || (origin[0] == "c" && origin[1] == "c") {
                self.view.window?.center()
            } else if (origin[0] == "f" && origin[1] == "f") {
                self.view.window?.toggleFullScreen(self)
                isFullScreen = true
            } else {
                self.view.window?.setFrameOrigin(NSPoint(x: Double(origin[0])!, y: Double(origin[1])!))
            }
            
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
            stopVM(false)
            return true;
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        let bounds = self.view.window!.contentView!.frame
        let resolution = "\(Int(bounds.width))x\(Int(bounds.height))x32"
        let origin = isFullScreen ? "f;f" : "\(Int(bounds.origin.x));\(Int(bounds.origin.y))"
        
        virtualMachine?.displayResolution = resolution
        virtualMachine?.displayOrigin = origin
        virtualMachine?.writeToPlist()
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        self.isFullScreen = true
    }
      
    func windowDidExitFullScreen(_ notification: Notification) {
        self.isFullScreen = false
    }
    
    func stopVM(_ closeWindow: Bool) {
        if let vmRunner = self.vmRunner {
            if vmRunner.isVMRunning() {
                vmRunner.stopVM(guestStopped: closeWindow)
            }
        }
        if let virtualMachine = virtualMachine {
            vmController?.cleanupStoppedVM(virtualMachine)
        }
        if closeWindow {
            self.view.window?.close();
        }
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
