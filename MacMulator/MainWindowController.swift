//
//  MainWindowController.swift
//  MacMulator
//
//  Created by Vale on 01/02/21.
//

import Cocoa

class MainWindowController: NSWindowController {
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if (segue.identifier == "newVMSegue") {
            let source: NSWindowController = segue.sourceController as! NSWindowController;
            let dest: NSWindowController = segue.destinationController as! NSWindowController;
            
            let sourceController: RootViewController = source.contentViewController as! RootViewController;
            let destinationController: NewVMViewController = dest.contentViewController as! NewVMViewController;
            
            destinationController.setRootController(sourceController);
        }
    }
}
