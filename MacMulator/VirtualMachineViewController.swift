//
//  VirtualMachineViewController.swift
//  MacMulator
//
//  Created by Vale on 27/01/21.
//

import Cocoa

class VirtualMachineViewController: NSViewController {
    
    var listenPort: Int32 = 4444;
    var vm : VirtualMachine?;
    var runner: QemuRunner?;
    var rootController: RootViewController?;
    var runners: [VirtualMachine: QemuRunner] = [:];
    
    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet weak var vmFilePath: NSTextField!
    @IBOutlet weak var vmResolution: NSTextField!
    @IBOutlet weak var vmMemory: NSTextField!
           
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    @IBAction
    func startVM(sender: NSButton) {
        
        if let vm = self.vm {
            if (runner!.isRunning()) {
                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                message: "Virtual Machine " + vm.displayName + " is already running!");
            } else {
                runner!.runVM(virtualMachine: vm, uponCompletion: {
                    self.runners.removeValue(forKey: vm)
                });
            }
        }
    }
    
    func escape(text: String) -> String {
        return text.replacingOccurrences(of: " ", with: "\\ ");
    }
    
    override func viewDidLoad() {
        super.viewDidLoad();
    }
    
    func setVirtualMachine(virtualMachine: VirtualMachine?) {
        if let vm = virtualMachine {
            self.vm = virtualMachine;
            vmName.stringValue = vm.displayName;
            vmFilePath.stringValue = vm.path;
            vmResolution.stringValue = vm.displayResolution;
            vmMemory.stringValue = String(vm.memory / 1024) + " GB";
            
            runner = runners[vm];
            if (runner == nil) {
                runner = QemuRunner();
                runner?.setListenPort(listenPort);
                runners[vm] = runner;
                listenPort += 1;
            }
        }
    }

}
