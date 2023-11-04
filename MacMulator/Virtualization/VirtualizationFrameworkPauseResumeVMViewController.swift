//
//  VirtualizationFrameworkPauseResumeVMViewController.swift
//  MacMulator
//
//  Created by Vale on 04/11/23.
//

import Cocoa

@available(macOS 12.0, *)
class VirtualizationFrameworkPauseResumeVMViewController: NSViewController {
    
    @IBOutlet weak var progressSpinner: NSProgressIndicator!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var vmIcon: NSImageView!
    
    var parentRunner: VirtualizationFrameworkVirtualMachineRunner?
    var operation: String?
    
    func setParentRunner(_ parentRunner: VirtualizationFrameworkVirtualMachineRunner) {
        self.parentRunner = parentRunner
    }
    
    func setOperation(_ operation: String) {
        self.operation = operation
    }
    
    override func viewDidLoad() {
        let vm = parentRunner?.managedVm
        if let vm = vm {
            self.vmIcon.image = NSImage.init(named: NSImage.Name(Utils.getIconForSubType(vm.os, vm.subtype) + ".large"))
        }
        
        progressSpinner.startAnimation(self)
        
        if self.operation == "Pausing" {
            descriptionLabel.stringValue = "Pausing VM and saving state..."
        } else {
            descriptionLabel.stringValue = "Resuming VM from saved state..."
        }
        
        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
                if let parentRunner = self.parentRunner {
                    if parentRunner.isVMRunning() {
                        self.dismiss(self)
                    }
                }
            })
        }
    }
}
