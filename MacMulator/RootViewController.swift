//
//  ViewController.swift
//  QManage
//
//  Created by Vale on 26/01/21.
//

import Cocoa

class RootViewController: NSSplitViewController {

  
    private var listController: VirtualMachinesListViewController?;
    private var vmController: VirtualMachineViewController?;
    
    override func viewDidLoad() {
        super.viewDidLoad();
    
        let children = self.children;
        
        listController = children[0] as? VirtualMachinesListViewController;
        if let listController = self.listController {
            listController.setRootController(self);
        }
        
        vmController = children[1] as? VirtualMachineViewController;
        if let vmController = self.vmController {
            vmController.setRootController(self);
        }
        
        let delegate = NSApp.delegate as! AppDelegate;
        delegate.rootControllerDidFinishLoading(self);
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func setCurrentVirtualMachine(_ currentVm: VirtualMachine?) {
        vmController?.setVirtualMachine(currentVm);
    }
    
    func addVirtualMachineFromFile(_ fileName: String) {
        let virtualMachine = VirtualMachine.readFromPlist(fileName, MacMulatorConstants.INFO_PLIST);
        virtualMachine?.path = fileName;
        if let vm = virtualMachine {
            self.addVirtualMachine(vm);
        }
    }
    
    func deleteVirtualMachine(_ virtualMachine: VirtualMachine) {
        vmController?.setVirtualMachine(nil);
        
        let delegate = NSApp.delegate as! AppDelegate;
        delegate.removeSavedVM(virtualMachine.path);
    }
    
    func addVirtualMachine(_ virtualMachine: VirtualMachine) {
        listController?.addVirtualMachine(virtualMachine);
        vmController?.setVirtualMachine(virtualMachine);
        
        let delegate = NSApp.delegate as! AppDelegate;
        delegate.addSavedVM(virtualMachine.path);
    }
    
    func showAlert(_ message: String) {
        Utils.showAlert(window: view.window!, style: NSAlert.Style.warning, message: message);
    }
    
    func refreshViewForVM(_ virtualMachine: VirtualMachine) {
        self.listController?.refreshList();
        if (vmController?.vm == virtualMachine) {
            vmController?.setVirtualMachine(virtualMachine);
        }
    }
}

