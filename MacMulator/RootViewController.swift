//
//  ViewController.swift
//  QManage
//
//  Created by Vale on 26/01/21.
//

import Cocoa

class RootViewController: NSSplitViewController {

    private let libraryPath = "/Volumes/valeMac\\ SSD/Parallels";
    private let qemuPath = "/opt/local/qemu";
        
    var listController: VirtualMachinesListViewController?;
    var vmController: VirtualMachineViewController?;
    
    override func viewDidLoad() {
        super.viewDidLoad();
        
        let userDefaults = UserDefaults.standard;
        userDefaults.set(libraryPath, forKey: "libraryPath");
        userDefaults.set(qemuPath, forKey: "qemuPath");
            
        let children = self.children;
        
        listController = children[0] as? VirtualMachinesListViewController;
        if let listController = self.listController {
            listController.setRootController(self);
        }
        
        vmController = children[1] as? VirtualMachineViewController;
        if let vmController = self.vmController {
            vmController.setRootController(self);
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
    
    func setCurrentVirtualMachine(_ currentVm: VirtualMachine) {
        if let vmController = self.vmController {
            vmController.setVirtualMachine(virtualMachine: currentVm);
        }
    }
    
    func addVirtualMachineFromFile(_ fileName: String) {
        let virtualMachine = VirtualMachine.readFromPlist(fileName + "/Info.plist");
        if let vm = virtualMachine {
            self.addVirtualMachine(vm);
        }
    }
    
    func addVirtualMachine(_ virtualMachine: VirtualMachine) {
        listController?.addVirtualMachine(virtualMachine);
        self.setCurrentVirtualMachine(virtualMachine);
    }
}

