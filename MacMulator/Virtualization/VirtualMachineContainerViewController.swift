//
//  VirtualMachineContainerViewController.swift
//  MacMulator
//
//  Created by Vale on 14/04/22.
//

import Cocoa

class VirtualMachineContainerViewController : NSViewController, VirtualMachineObserver, NSWindowDelegate {
    
    var virtualMachine: VirtualMachine?
    var vmController: VirtualMachineViewController?
    var runner: VirtualizationFrameworkVirtualMachineRunner?;
    
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
    }
    
    func setVmController(_ controller: VirtualMachineViewController) {
        vmController = controller;
    }
    
    override func viewWillAppear() {
        self.view.window?.delegate = self;
        
        if let virtualMachine = virtualMachine {
            let resolution = Utils.getResolutionElements(virtualMachine.displayResolution);
            self.view.window?.setContentSize(CGSize(width: resolution[0], height: resolution[1]));
            self.view.window?.setFrameOrigin(NSPoint(x: 200, y: 200));
            
            runner = vmController?.rootController?.getRunnerForRunningVM(virtualMachine) as? VirtualizationFrameworkVirtualMachineRunner;
            runner?.addObserver(self);
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let response = Utils.showPrompt(window: self.view.window!, style: NSAlert.Style.warning, message: "Closing this wiondow will forcibly kill the running VM.\nIt is strogly suggested to shut it down gracefully using the guest OS shut down procedure, or you might loose your unsaved work.\n\nDo you want to continue?");
        if response.rawValue != Utils.ALERT_RESP_OK {
            return false;
        } else {
            runner?.stopVM();
            return true;
        }
    }
    
    func virtualMachineStarted() {
        
    }
    
    func virtualmachinePaused() {
        
    }
    
    func virtualMachineStopped() {
        self.view.window?.close();
    }
}
