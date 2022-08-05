//
//  EditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewController: NSTabViewController {
    
    var rootController : RootViewController?
    var virtualMachine: VirtualMachine?
    
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
        
        let general = tabViewItems[0].viewController as! EditVMViewControllerGeneral
        let hardware = tabViewItems[1].viewController as! EditVMViewControllerHardware
        let advanced = tabViewItems[2].viewController as! EditVMViewControllerAdvanced
        
        general.setVirtualMachine(vm);
        hardware.setVirtualMachine(vm);
        advanced.setVirtualMachine(vm);
        
        if Utils.isVirtualizationFrameworkPreferred(vm) {
            removeTabViewItem(tabViewItems[2])
        }
    }
    
    override func viewWillDisappear() {
        virtualMachine?.writeToPlist();
    }
    
    override func viewDidDisappear() {
        if let virtualMachine = self.virtualMachine {
            virtualMachine.writeToPlist();
            rootController?.refreshViewForVM(virtualMachine);
        }
    }
}
