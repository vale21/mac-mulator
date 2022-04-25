//
//  VirtualMachineContainerViewController.swift
//  MacMulator
//
//  Created by Vale on 14/04/22.
//

import Cocoa
import Virtualization

@available(macOS 12.0, *)
class VirtualMachineContainerViewController : NSViewController, VirtualMachineObserver, NSWindowDelegate {
    
    var virtualMachine: VirtualMachine?
    var vmController: VirtualMachineViewController?
    @IBOutlet weak var vmView: VZVirtualMachineView!
    
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
    }
    
    func setVmController(_ controller: VirtualMachineViewController) {
        vmController = controller;
    }
    
    override func viewDidAppear() {
        self.view.window?.delegate = self;
        
        if let virtualMachine = virtualMachine {
            let resolution = Utils.getResolutionElements(virtualMachine.displayResolution);
            self.view.window?.setContentSize(CGSize(width: resolution[0], height: resolution[1]));
            self.view.window?.setFrameOrigin(NSPoint(x: 200, y: 200));
            
            
            let vmRunner = VirtualMachineRunnerFactory().create(listenPort: 0, vm: virtualMachine) as! VirtualizationFrameworkVirtualMachineRunner;
            //runner = vmController?.rootController?.getRunnerForRunningVM(virtualMachine) as? VirtualizationFrameworkVirtualMachineRunner;
            //runner?.addObserver(self);
            vmRunner.setVmView(vmView);
            vmRunner.runVM(uponCompletion: {
                result, virtualMachine in
                DispatchQueue.main.async {
                    if (result.exitCode != 0) {
                        Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: "Qemu execution failed with error: " + result.error!);
                    }
                    else {
                        self.view.window?.close();
                    }
                }
            });
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let response = Utils.showPrompt(window: self.view.window!, style: NSAlert.Style.warning, message: "Closing this wiondow will forcibly kill the running VM.\nIt is strogly suggested to shut it down gracefully using the guest OS shut down procedure, or you might loose your unsaved work.\n\nDo you want to continue?");
        if response.rawValue != Utils.ALERT_RESP_OK {
            return false;
        } else {
            //runner?.stopVM();
            return true;
        }
    }
    
    func virtualMachineStarted(_ vm: VZVirtualMachine) {
        vmView?.virtualMachine = vm;
    }
    
    func virtualmachinePaused(_ vm: VZVirtualMachine) {
        
    }
    
    func virtualMachineStopped(_ vm: VZVirtualMachine) {
        self.view.window?.close();
    }
}
