//
//  StartVMProgressViewController.swift
//  MacMulator
//
//  Created by Vale on 14/06/24.
//

import Cocoa

class StartVMViewController: NSViewController, RunningVMManagerViewController {
    
    @IBOutlet weak var progressBar: NSProgressIndicator!
    
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
        progressBar.startAnimation(self);
        var complete = false;
        
        if let virtualMachine = virtualMachine {
            if let vmRunner = vmRunner {
                QemuUtils.populateOpenCoreConfig(virtualMachine: virtualMachine, uponCompletion: {
                    terminationCode in
                    if terminationCode == 0 {
                        complete = true
                    }
                });
                
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
                    
                    guard !complete else {
                        timer.invalidate();
                        self.progressBar.stopAnimation(self);
                        self.dismiss(self);
                        
                        self.vmController!.startVMPrerequisitesCompleted(vmRunner, self.recoveryMode, virtualMachine)
                        return;
                    }
                });
            }
        }
    }
}

