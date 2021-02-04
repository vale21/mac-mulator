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
    var rootController: RootViewController?;
    var runningVMs: [VirtualMachine : Bool] = [:];

    @IBOutlet weak var vmIcon: NSImageView!
    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet weak var vmFilePathDesc: NSTextField!
    @IBOutlet weak var vmFilePath: NSTextField!
    @IBOutlet weak var vmResolutionDesc: NSTextField!
    @IBOutlet weak var vmResolution: NSTextField!
    @IBOutlet weak var vmMemoryDesc: NSTextField!
    @IBOutlet weak var vmMemory: NSTextField!
    @IBOutlet weak var startVMButton: NSButton!
    @IBOutlet weak var runningProgress: NSProgressIndicator!
    @IBOutlet weak var runningLabel: NSTextField!
    @IBOutlet weak var noVMView: NSView!
    
    override func viewWillAppear() {
        self.setRunningStatus(false);
        if let vm = self.vm {
            changeStatusOfAllControls(hidden: false);
            startVMButton.isHidden = false;
        } else {
            changeStatusOfAllControls(hidden: true);
            startVMButton.isHidden = true;
        }
    }
    
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    @IBAction
    func startVM(sender: NSButton) {
        
        if let vm = self.vm {
            runningVMs[vm] = true;
            let runner = QemuRunner();
            runner.setListenPort(listenPort);
            listenPort += 1;
            if (runner.isRunning()) {
                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                message: "Virtual Machine " + vm.displayName + " is already running!");
            } else {
                self.setRunningStatus(true);
                runner.runVM(virtualMachine: vm, uponCompletion: {
                    virtualMachine in
                    self.runningVMs.removeValue(forKey: virtualMachine);
                    self.setRunningStatus(false);
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
    
    func setVirtualMachine(_ virtualMachine: VirtualMachine?) {
        if let vm = virtualMachine {
            self.vm = virtualMachine;
            vmName.stringValue = vm.displayName;
            vmFilePath.stringValue = vm.path;
            vmResolution.stringValue = vm.displayResolution;
            vmMemory.stringValue = String(vm.memory / 1024) + " GB";
            
            if (runningVMs[vm] == true) {
                setRunningStatus(true);
            } else {
                setRunningStatus(false);
            }
            changeStatusOfAllControls(hidden: false);
        }
    }
    
    fileprivate func setRunningStatus(_ running: Bool) {
        self.startVMButton.isHidden = running;
        self.runningProgress.isHidden = !running;
        self.runningLabel.isHidden = !running;
        if (running) {
            self.runningProgress.startAnimation(self);
        } else {
            self.runningProgress.stopAnimation(self);
        }
    }

    fileprivate func changeStatusOfAllControls(hidden: Bool) {
        vmIcon.isHidden = hidden;
        vmName.isHidden = hidden;
        vmFilePathDesc.isHidden = hidden;
        vmFilePath.isHidden = hidden;
        vmResolutionDesc.isHidden = hidden;
        vmResolution.isHidden = hidden;
        vmMemoryDesc.isHidden = hidden;
        vmMemory.isHidden = hidden;
        noVMView.isHidden = !hidden;
    }
    
    @IBAction func createVMButtonClicked(_ sender: Any) {
        self.view.window?.windowController?.performSegue(withIdentifier: "newVMSegue", sender: self);
    }
    
    @IBAction func importVMButtonClicked(_ sender: Any) {
        Utils.showFileSelector(fileTypes: ["qvm"], uponSelection: { panel in NSApp.delegate?.application!(NSApp, openFile: String(panel.url!.path)) });
    }
}
