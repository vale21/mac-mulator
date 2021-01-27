//
//  ViewController.swift
//  QManage
//
//  Created by Vale on 26/01/21.
//

import Cocoa

class RootViewController: NSSplitViewController {

    private var libraryPath = "/Volumes/valeMac\\ SSD/Parallels";
    private var qemuPath = "/opt/local/qemu/qemu-system-ppc";
        
    override func viewDidLoad() {
        super.viewDidLoad();
        
        let children = self.children;
        
        let vmController: VirtualMachineViewController = children[1] as! VirtualMachineViewController;
        vmController.setRootController(rootController: self);
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
}

