//
//  VirtualMachineTableCellView.swift
//  MacMulator
//
//  Created by Vale on 28/01/21.
//

import Cocoa

class VirtualMachineTableCellView: NSTableCellView {

    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet weak var vmIcon: NSImageView!
    @IBOutlet weak var runningSpinner: NSProgressIndicator!
    
    var virtualMachine: VirtualMachine?;
    
    func setVirtualMachine(virtualMachine: VirtualMachine) {
        self.virtualMachine = virtualMachine;
        vmName.stringValue = virtualMachine.displayName;
        vmIcon.image = NSImage.init(named: NSImage.Name(virtualMachine.os + "-small"));
        runningSpinner.isHidden = true;
    }
    
    func setRunning(_ running: Bool) {
        if running {
            runningSpinner.isHidden = false;
            runningSpinner.startAnimation(self);
            vmIcon.isHidden = true;
        } else {
            runningSpinner.isHidden = true;
            runningSpinner.stopAnimation(self);
            vmIcon.isHidden = false;
        }
    }
}
