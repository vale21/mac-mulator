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
        progressBar.startAnimation(self)
        var openCoreComplete = false
        var uefiComplete = false
        var uefiSecureComplete = false
        
        if let virtualMachine = virtualMachine {
            if let vmRunner = vmRunner {
                
                if virtualMachine.bootMode == QemuConstants.BOOT_UEFI {
                    QemuUtils.removeUEFISecureConfig(virtualMachine: virtualMachine)
                    QemuUtils.populateUEFIConfig(virtualMachine: virtualMachine)
                    uefiSecureComplete = true
                    uefiComplete = true
                } else if virtualMachine.bootMode == QemuConstants.BOOT_UEFI_SECURE {
                    QemuUtils.removeUEFIConfig(virtualMachine: virtualMachine)
                    QemuUtils.populateUEFISecureConfig(virtualMachine: virtualMachine)
                    uefiComplete = true
                    uefiSecureComplete = true
                } else {
                    uefiComplete = true
                    uefiSecureComplete = true
                }
                
                if QemuUtils.requiresOpenCore(virtualMachine) {
                    QemuUtils.populateOpenCoreConfig(virtualMachine: virtualMachine, uponCompletion: {
                        terminationCode in
                        if terminationCode == 0 {
                            openCoreComplete = true
                        }
                    })
                } else {
                    openCoreComplete = true
                }
                
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
                    let complete = openCoreComplete && uefiComplete && uefiSecureComplete
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

