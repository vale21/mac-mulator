//
//  MainWindowController.swift
//  MacMulator
//
//  Created by Vale on 01/02/21.
//

import Cocoa

class MainWindowController: NSWindowController {
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        let source = segue.sourceController as! NSWindowController;
        let dest = segue.destinationController as! NSWindowController;
        let sourceController = source.contentViewController as! RootViewController;
        
        if (segue.identifier == MacMulatorConstants.NEW_VM_SEGUE) {
            let destinationController = dest.contentViewController as! NewVMViewController;
            //destinationController.setRootController(sourceController);
        }
        if (segue.identifier == MacMulatorConstants.EDIT_VM_SEGUE) {
            let vmToEdit = sender as! VirtualMachine;
            
            let destinationController = dest.contentViewController as! EditVMViewController;
            destinationController.setVirtualMachine(vmToEdit);
            destinationController.setRootController(sourceController);
        }
    }
}
