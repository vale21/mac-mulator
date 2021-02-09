//
//  MainWindowController.swift
//  MacMulator
//
//  Created by Vale on 01/02/21.
//

import Cocoa

class MainWindowController: NSWindowController {
    
    static let NEW_VM_SEGUE = "newVMSegue";

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if (segue.identifier == MainWindowController.NEW_VM_SEGUE) {
            let source: NSWindowController = segue.sourceController as! NSWindowController;
            let dest: NSWindowController = segue.destinationController as! NSWindowController;
            
            let sourceController: RootViewController = source.contentViewController as! RootViewController;
            let destinationController: NewVMViewController = dest.contentViewController as! NewVMViewController;
            
            destinationController.setRootController(sourceController);
        }
    }
}
