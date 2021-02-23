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
    @IBOutlet weak var vmDescription: NSTextField!
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
        if self.vm != nil {
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
            let runner = QemuRunner(listenPort: listenPort, virtualMachine: vm);
            listenPort += 1;
            if (runner.isRunning()) {
                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                message: "Virtual Machine " + vm.displayName + " is already running!");
            } else {
                self.setRunningStatus(true);
                runner.runVM(uponCompletion: {
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
            
            vmIcon.image = NSImage.init(named: NSImage.Name(vm.os));
            vmName.stringValue = vm.displayName;
            vmDescription.stringValue = vm.description ?? "";
            vmResolution.stringValue = vm.displayResolution;
            vmMemory.stringValue = Utils.formatMemory(vm.memory);
            
            if (runningVMs[vm] == true) {
                setRunningStatus(true);
            } else {
                setRunningStatus(false);
            }
            changeStatusOfAllControls(hidden: false);
        } else {
            changeStatusOfAllControls(hidden: true);
            startVMButton.isHidden = true;
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
        vmDescription.isHidden = hidden;
        vmResolutionDesc.isHidden = hidden;
        vmResolution.isHidden = hidden;
        vmMemoryDesc.isHidden = hidden;
        vmMemory.isHidden = hidden;
        noVMView.isHidden = !hidden;
    }
    
    @IBAction func createVMButtonClicked(_ sender: Any) {
        self.view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.NEW_VM_SEGUE, sender: self);
    }
    
    @IBAction func importVMButtonClicked(_ sender: Any) {
        Utils.showFileSelector(fileTypes: [MacMulatorConstants.VM_EXTENSION], uponSelection: { panel in NSApp.delegate?.application!(NSApp, openFile: String(panel.url!.path)) });
    }
}
