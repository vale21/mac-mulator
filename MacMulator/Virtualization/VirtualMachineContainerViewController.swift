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
    var vmController: VirtualMachineViewController?
    var vmRunner: VirtualizationFrameworkVirtualMachineRunner?
 
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
    }
    
    func setVmController(_ controller: VirtualMachineViewController) {
        vmController = controller;
    }
    
    func setVmRunner(_ runner: VirtualizationFrameworkVirtualMachineRunner) {
        vmRunner = runner
    }
    
    override func viewDidAppear() {
        self.view.window?.delegate = self;
        self.view.window?.title = virtualMachine?.displayName ?? "MacMulator"
        
        if let virtualMachine = virtualMachine {
            let resolution = Utils.getResolutionElements(virtualMachine.displayResolution);
            self.view.window?.setContentSize(CGSize(width: resolution[0], height: resolution[1]));
            self.view.window?.setFrameOrigin(NSPoint(x: 200, y: 200));
            
            if let vmRunner = self.vmRunner {
                vmRunner.setVmView(self.view as! VZVirtualMachineView);
                vmRunner.setVmViewController(self);
                vmRunner.runVM(uponCompletion: {
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
}
