//
//  NewVMViewController.swift
//  MacMulator
//
//  Created by Vale on 19/04/21.
//

import Cocoa

class NewVMViewController : NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTextViewDelegate {
    
    @IBOutlet weak var vmType: NSComboBox!
    @IBOutlet weak var vmSubType: NSComboBox!
    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet var vmDescription: NSTextView!
    @IBOutlet weak var installMedia: NSTextField!
    @IBOutlet weak var fullConfiguration: NSButton!
    
    var rootController : RootViewController?
    
    static let DESCRIPTION_DEFAULT_MESSAGE = "You can type here to write a description of your VM...";
        
    @IBAction func findInstallMedia(_ sender: Any) {
        Utils.showFileSelector(fileTypes: Utils.IMAGE_TYPES, uponSelection: { panel in
            if let path = panel.url?.path {
                installMedia.stringValue = path;
            }
        });
    }
    
    @IBAction func createVM(_ sender: Any) {
        if (vmType.stringValue == "" || vmName.stringValue == "") {
            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: "You did not provide values for VM type or VM name. These fields are required to create a new Virtual Machine. Please provide a value for them and try again.");
        } else if (rootController?.getVirtualMachine(name: vmName.stringValue) != nil) {
            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: "A Virtual machine called " + vmName.stringValue + " already exists. Please choose a different name.");
        } else {
            #if arch(arm64)
            
            if #available(macOS 12.0, *) {
                if (vmType.stringValue == QemuConstants.OS_MAC &&
                    (vmSubType.stringValue == QemuConstants.SUB_MAC_MONTEREY ||
                     vmSubType.stringValue == QemuConstants.SUB_MAC_VENTURA) && // TODO fix this to use Utils.isVirtualizationFrameworkPreferred method
                    !Utils.isIpswInstallMediaProvided(installMedia.stringValue)) {
                    let response = Utils.showPrompt(window: self.view.window!, style: NSAlert.Style.warning, message: "You did not specify an install media for macOS. MacMulator will download the latest supported version of macOS from Apple at the first start of the VM. Do you agree?");
                    if response.rawValue == Utils.ALERT_RESP_OK {
                        performSegue(withIdentifier: MacMulatorConstants.CREATE_VM_FILE_SEGUE, sender: self);
                    } else {
                        return;
                    }
                } else {
                    performSegue(withIdentifier: MacMulatorConstants.CREATE_VM_FILE_SEGUE, sender: self);
                }
            }
            #else
            
            performSegue(withIdentifier: MacMulatorConstants.CREATE_VM_FILE_SEGUE, sender: self);
            
            #endif
        }
    }
    
    override func viewWillAppear() {
        vmSubType.stringValue = QemuConstants.SUB_OTHER_GENERIC;
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if (segue.identifier == MacMulatorConstants.CREATE_VM_FILE_SEGUE) {
            let destinationController = segue.destinationController as! CreateVMFileViewController;
            destinationController.setParentController(self);
        }
    }
    
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        if comboBox == vmType {
            return QemuConstants.supportedVMTypes.count;
        }
        return vmType == nil ? 1 : Utils.countSubTypes(vmType.stringValue);
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if comboBox == vmType {
            return QemuConstants.supportedVMTypes[index];
        }
        return vmType == nil ? 1 : Utils.getSubType(vmType.stringValue, index);
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        if notification.object as? NSComboBox == vmType {
            vmSubType.stringValue = Utils.getSubType(comboBox(vmType, objectValueForItemAt: vmType.indexOfSelectedItem) as? String, 0);
            vmSubType.reloadData();
        }
    }
        
    func textViewDidChangeSelection(_ notification: Notification) {
        if (vmDescription.string == NewVMViewController.DESCRIPTION_DEFAULT_MESSAGE) {
            vmDescription.string = "";
        }
    }
    
    func vmCreated(_ vm: VirtualMachine) {
        rootController?.addVirtualMachine(vm);
        if fullConfiguration.state == NSControl.StateValue.on {
            rootController?.view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.EDIT_VM_SEGUE, sender: vm);
        }
        self.view.window?.close();
    }
}
