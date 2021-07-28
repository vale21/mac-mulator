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
            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: "You did not provide values for VM type or VM name. These fields are required to create a new Virtual Machine. Please provide a value for them and try again.")
        } else {
            performSegue(withIdentifier: MacMulatorConstants.CREATE_VM_FILE_SEGUE, sender: self);
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
