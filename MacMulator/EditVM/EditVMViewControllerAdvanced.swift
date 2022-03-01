//
//  GeneralEditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewControllerAdvanced: NSViewController, NSTextFieldDelegate, NSTextViewDelegate {
    
    @IBOutlet weak var qemuPathView: NSTextField!
    @IBOutlet weak var accelerateVM: NSButton!
    @IBOutlet weak var qemuPathButton: NSButton!
    @IBOutlet var fullCommandView: NSTextView!

    var virtualMachine: VirtualMachine?;
       
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
        updateView()
    }
    
    @IBAction func findButtonClicked(_ sender: Any) {
        Utils.showDirectorySelector(uponSelection: {
            panel in
            if let path = panel.url?.path {
                qemuPathView.stringValue = path;
                virtualMachine?.qemuPath = path;
                updateView();
            }
        });
    }
    
    @IBAction func accelerateToggleChanged(_ sender: Any) {
        if let virtualMachine = self.virtualMachine {
            virtualMachine.hvf = self.accelerateVM.state == NSButton.StateValue.on;
        }
    }
    
    override func viewWillAppear() {
        updateView();
    }
    
    fileprivate func updateView() {
        if let virtualMachine = self.virtualMachine {
            let runner = QemuRunner(listenPort: 4444, virtualMachine: virtualMachine);
            fullCommandView.string = runner.getQemuCommand();
            if let qemuPath = virtualMachine.qemuPath {
                qemuPathView.stringValue = qemuPath;
            } else {
                qemuPathView.stringValue = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
            }
            if let hvf = virtualMachine.hvf {
                self.accelerateVM.state = (hvf ? NSButton.StateValue.on : NSButton.StateValue.off);
            } else {
                self.accelerateVM.state = NSButton.StateValue.on;
            }
        }
    }
    
    func controlTextDidChange(_ notification: Notification) {
        if ((notification.object as! NSTextField) == qemuPathView) {
            if let virtualMachine = self.virtualMachine {
                let originalPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH);
               
                if qemuPathView.stringValue != originalPath {
                    if qemuPathView.stringValue != "" {
                        virtualMachine.qemuPath = qemuPathView.stringValue;
                    } else {
                        virtualMachine.qemuPath = nil;
                    }
                } else {
                    virtualMachine.qemuPath = nil;
                }
            }
        }
        
        updateView();
    }
    
    func textDidChange(_ notification: Notification) {
        if (notification.object as? NSTextView) == fullCommandView {
            if let virtualMachine = self.virtualMachine {
                let runner = QemuRunner(listenPort: 4444, virtualMachine: virtualMachine);
                let originalCommand = runner.getQemuCommand();
               
                if fullCommandView.string != originalCommand {
                    if fullCommandView.string != "" {
                        virtualMachine.qemuCommand = fullCommandView.string;
                    } else {
                        virtualMachine.qemuCommand = nil;
                    }
                } else {
                    virtualMachine.qemuCommand = nil;
                }
            }
        }
    }
}


