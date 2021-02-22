//
//  MainWindowController.swift
//  MacMulator
//
//  Created by Vale on 01/02/21.
//

import Cocoa

class MainWindowController: NSWindowController {
    
    static let NEW_VM_SEGUE = "newVMSegue";
    static let EDIT_VM_SEGUE = "editVMSegue";

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        let source = segue.sourceController as! NSWindowController;
        let dest = segue.destinationController as! NSWindowController;
        let sourceController = source.contentViewController as! RootViewController;
        
        if (segue.identifier == MainWindowController.NEW_VM_SEGUE) {
            let destinationController = dest.contentViewController as! NewVMViewController;
            destinationController.setRootController(sourceController);
        }
        if (segue.identifier == MainWindowController.EDIT_VM_SEGUE) {
            let vmToEdit = sender as! VirtualMachine;
            
            let destinationController = dest.contentViewController as! EditVMViewController;
            destinationController.setVirtualMachine(vmToEdit);
            destinationController.setRootController(sourceController);
        }
    }
}
