//
//  ViewController.swift
//  QManage
//
//  Created by Vale on 26/01/21.
//

import Cocoa

class RootViewController: NSSplitViewController {

    private let libraryPath = "/Volumes/valeMac\\ SSD/Parallels";
    private let qemuPath = "/opt/local/qemu/qemu-system-ppc";
        
    var listController: VirtualMachinesListViewController?;
    var vmController: VirtualMachineViewController?;
    
    override func viewDidLoad() {
        super.viewDidLoad();
            
        let children = self.children;
        
        let virm = VirtualMachine(name:"tiger", displayName: "Mac OS X Tiger", memory: 2048, resolution: "1440x900x32", bootArg: "c");
        let drive = VirtualDrive(name:"disk-0", format: "qcow2", mediaType: "disk");
        virm.addVirtualDrive(drive: drive);
        
        let virm2 = VirtualMachine(name:"panther", displayName: "Mac OS X Panther", memory: 1024, resolution: "1440x900x32", bootArg: "c");
        let drive2 = VirtualDrive(name:"panther", format: "qcow2", mediaType: "disk");
        virm2.addVirtualDrive(drive: drive2);
        
        listController = children[0] as? VirtualMachinesListViewController;
        if let listController = self.listController {
            listController.setRootController(rootController: self);
            listController.addVirtualMachine(virtualMachine: virm);
            listController.addVirtualMachine(virtualMachine: virm2);
        }
        
        vmController = children[1] as? VirtualMachineViewController;
        if let vmController = self.vmController {
            vmController.setRootController(rootController: self);
            vmController.setVirtualMachine(virtualmachine: virm);
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func getLibraryPath() -> String {
        return libraryPath;
    }
    
    func getQemuPath() -> String {
        return qemuPath;
    }
    
    func setCurrentVirtualMachine(currentVm: VirtualMachine) {
        if let vmController = self.vmController {
            vmController.setVirtualMachine(virtualmachine: currentVm);
        }
    }
}

