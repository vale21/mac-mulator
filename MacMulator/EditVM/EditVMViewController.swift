//
//  EditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewController: NSTabViewController {
    var rootController: RootViewController?
    var virtualMachine: VirtualMachine?

    func setRootController(_ rootController: RootViewController) {
        self.rootController = rootController
        let hardware = tabViewItems[1].viewController as! EditVMViewControllerHardware
        hardware.setRootController(rootController)
    }

    func setVirtualMachine(_ vm: VirtualMachine) {
        view.window?.title = String(format: NSLocalizedString("EditVMViewController.windowTitle", comment: ""), vm.displayName)

        virtualMachine = vm

        tabViewItems[0].label = NSLocalizedString("EditVMViewController.general", comment: "")
        tabViewItems[1].label = NSLocalizedString("EditVMViewController.hardware", comment: "")
        tabViewItems[2].label = NSLocalizedString("EditVMViewController.network", comment: "")
        tabViewItems[3].label = NSLocalizedString("EditVMViewController.network", comment: "")
        tabViewItems[4].label = NSLocalizedString("EditVMViewController.video", comment: "")
        tabViewItems[5].label = NSLocalizedString("EditVMViewController.advanced", comment: "")

        let general = tabViewItems[0].viewController as! EditVMViewControllerGeneral
        let hardware = tabViewItems[1].viewController as! EditVMViewControllerHardware
        let network = tabViewItems[2].viewController as! EditVMViewControllerNetwork
        let networkVF = tabViewItems[3].viewController as! EditVMViewControllerNetworkVF
        let video = tabViewItems[4].viewController as! EditVMViewControllerVideo
        let advanced = tabViewItems[5].viewController as! EditVMViewControllerAdvanced

        general.setVirtualMachine(vm)
        hardware.setVirtualMachine(vm)
        network.setVirtualMachine(vm)
        networkVF.setVirtualMachine(vm)
        video.setVirtualMachine(vm)
        advanced.setVirtualMachine(vm)

        if vm.type == MacMulatorConstants.APPLE_VM {
            removeTabViewItem(tabViewItems[5])
            removeTabViewItem(tabViewItems[4])
            removeTabViewItem(tabViewItems[2])
        } else if vm.os == QemuConstants.OS_IOS {
            removeTabViewItem(tabViewItems[4])
            removeTabViewItem(tabViewItems[3])
            removeTabViewItem(tabViewItems[2])
        } else if vm.os != QemuConstants.OS_LINUX, vm.subtype != QemuConstants.SUB_WINDOWS_11 {
            removeTabViewItem(tabViewItems[4])
            removeTabViewItem(tabViewItems[3])
        } else {
            removeTabViewItem(tabViewItems[3])
        }
    }

    override func viewWillDisappear() {
        virtualMachine?.writeToPlist()
    }

    override func viewDidDisappear() {
        if let virtualMachine {
            virtualMachine.writeToPlist()
            rootController?.refreshViewForVM(virtualMachine)
        }
    }
}
