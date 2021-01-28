//
//  VirtualMachineTableCellView.swift
//  MacMulator
//
//  Created by Vale on 28/01/21.
//

import Cocoa

class VirtualMachineTableCellView: NSTableCellView {

    @IBOutlet weak var vmName: NSTextField!
    
    var virtualMachine: VirtualMachine?;
    
    func setVirtualMachine(virtualMachine: VirtualMachine) {
        self.virtualMachine = virtualMachine;
        vmName.stringValue = virtualMachine.displayName;
    }
}
