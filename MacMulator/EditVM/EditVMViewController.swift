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
        let network = tabViewItems[2].viewController as! EditVMViewControllerNetwork
        let video = tabViewItems[3].viewController as! EditVMViewControllerVideo
        let advanced = tabViewItems[4].viewController as! EditVMViewControllerAdvanced
        
        general.setVirtualMachine(vm)
        hardware.setVirtualMachine(vm)
        network.setVirtualMachine(vm)
        video.setVirtualMachine(vm)
        advanced.setVirtualMachine(vm)
        
        if vm.type == MacMulatorConstants.APPLE_VM {
            removeTabViewItem(tabViewItems[4])
            removeTabViewItem(tabViewItems[3])
            removeTabViewItem(tabViewItems[2])
        } else if vm.os == QemuConstants.OS_IOS {
            removeTabViewItem(tabViewItems[3])
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
