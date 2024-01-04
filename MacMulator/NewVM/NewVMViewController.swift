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
    @IBOutlet weak var obtainOSButton: NSButton!
    @IBOutlet weak var fullConfiguration: NSButton!
    
    var rootController : RootViewController?
    
    static let DESCRIPTION_DEFAULT_MESSAGE = NSLocalizedString("NewVMViewController.defaultMessage", comment: "")
    
    @IBAction func findInstallMedia(_ sender: Any) {
        Utils.showFileSelector(fileTypes: Utils.IMAGE_TYPES, uponSelection: { panel in
            if let path = panel.url?.path {
                installMedia.stringValue = path;
            }
        });
    }
    
    @IBAction func downloadInstallMedia(_ sender: Any) {
        let url = URL(string: Utils.getIUrlForSubType(vmType.stringValue, vmSubType.stringValue))!
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func createVM(_ sender: Any) {
        if (validateInput()) {
            if Utils.isMacVMWithOSVirtualizationFramework(os: vmType.stringValue, subtype: vmSubType.stringValue) && !Utils.isIpswInstallMediaProvided(installMedia.stringValue) {
                let response = Utils.showPrompt(window: self.view.window!, style: NSAlert.Style.warning, message: NSLocalizedString("NewVMController.noMediaProvided", comment: ""));
                
                if response.rawValue == Utils.ALERT_RESP_OK {
                    performSegue(withIdentifier: MacMulatorConstants.CREATE_VM_FILE_SEGUE, sender: self);
                } else {
                    return;
                }
            } else {
                performSegue(withIdentifier: MacMulatorConstants.CREATE_VM_FILE_SEGUE, sender: self);
            }
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
            
            if comboBox(vmType, objectValueForItemAt: vmType.indexOfSelectedItem) as! String == QemuConstants.OS_OTHER {
                obtainOSButton.isEnabled = false
            } else {
                obtainOSButton.isEnabled = true
            }
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
    
    func vmCreationfFailed(_ vm: VirtualMachine, _ error: Error) {
        Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: NSLocalizedString("NewVMController.vmCreationFailed", comment: "") + error.localizedDescription, completionHandler: {resp in self.view.window?.close()})
    }
    
    fileprivate func validateInput() -> Bool {
        if (vmType.stringValue == "" || vmName.stringValue == "") {
            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: NSLocalizedString("NewVMController.errorFeldsMissing", comment: ""));
            return false
        } else if (rootController?.getVirtualMachine(name: vmName.stringValue) != nil) {
            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("NewVMController.errorVMExisting", comment: ""), vmName.stringValue));
            return false
        } else if (FileManager.default.fileExists(atPath: Utils.computeVMPath(vmName: vmName.stringValue))) {
            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("NewVMController.errorFileExisting", comment: ""), Utils.computeVMPath(vmName: vmName.stringValue)));
            return false
        } else {
            return true
        }
    }
}
