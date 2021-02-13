//
//  EditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewController: NSTabViewController {
    
    var virtualMachine: VirtualMachine?
    
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
        
        let general = tabViewItems[0].viewController as! EditVMViewControllerGeneral
        
        print(general);
        general.setVirtualMachine(vm);
    }
    
    override func viewWillDisappear() {
        virtualMachine?.writeToPlist();
    }
}
