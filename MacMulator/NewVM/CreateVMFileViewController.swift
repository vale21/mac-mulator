//
//  CreateVMFileViewController.swift
//  MacMulator
//
//  Created by Vale on 21/04/21.
//

import Cocoa
import ZIPFoundation

class CreateVMFileViewController : NSViewController {
    
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var descriptionLabel: NSTextField!
    
    var parentController: NewVMViewController?;
    
    func setParentController(_ parentController: NewVMViewController) {
        self.parentController = parentController;
    }
    
    fileprivate func creationComplete(_ timer: Timer, _ foundError: Bool, _ vm: VirtualMachine) {
        timer.invalidate();
        self.progressBar.stopAnimation(self);
        self.dismiss(self);
        
        if !foundError {
            self.parentController!.vmCreated(vm);
        }
    }
    
    override func viewDidAppear() {
        progressBar.startAnimation(self);
        
        if let parentController = self.parentController {
            let os = parentController.vmType.stringValue;
            let subtype = parentController.vmSubType.stringValue;
            let architecture = Utils.getArchitectureForSubType(os, subtype);
            let path = computePath();
            let displayName = parentController.vmName.stringValue;
            let description = computeDescription();
            let memory = Utils.getDefaultMemoryForSubType(os, subtype);
            let cpus = Utils.getCpusForSubType(os, subtype);
            let displayResolution = QemuConstants.RES_1280_768;
            
            let vm = VirtualMachine(os: os, subtype: subtype, architecture: architecture, path: path, displayName: displayName, description: description, memory: Int32(memory), cpus: cpus, displayResolution: displayResolution, qemuBootloader: false, hvf: Utils.getAccelForSubType(os, subtype));
            
//            if Utils.isVirtualizationFrameworkPreferred(vm) {
//                progressBar.isIndeterminate = false
//                progressBar.doubleValue = 0
//                progressBar.minValue = 0
//                progressBar.maxValue = 100
//            }
            
            var foundError: Bool = false;
            
            if let parentController = self.parentController {
                
                let vmCreator: VMCreator = VMCreatorFactory().create(vm: vm);
                
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
                    
//                    if (Utils.isVirtualizationFrameworkPreferred(vm)) {
//                        let currentValue = self.progressBar.doubleValue
//                        let newValue = vmCreator.creationProgress()
//                        self.descriptionLabel.stringValue = "Creating new Virtual Machine (" + String(Int(newValue)) + "%)..."
//                        if (newValue > currentValue) {
//                            let delta = newValue - currentValue;
//                            self.progressBar.increment(by: delta)
//                        }
//                        if (vmCreator.isComplete()) {
//                            self.creationComplete(timer, foundError, vm)
//                        }
//                    } else {
                        guard !vmCreator.isComplete() else {
                            self.creationComplete(timer, foundError, vm)
                            return;
                        }
//                    }
                });
                
                let installMedia = parentController.installMedia.stringValue;
                DispatchQueue.global().async {
                    do {
                        try vmCreator.createVM(vm: vm, installMedia: installMedia);
                    } catch {
                        foundError = true;
                        DispatchQueue.main.async {
                            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                            message: "Unable to create Virtual Machine " + vm.displayName + ": " + error.localizedDescription);
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func computePath() -> String {
        let userDefaults = UserDefaults.standard;
        let path = userDefaults.string(forKey: MacMulatorConstants.PREFERENCE_KEY_VMS_FOLDER_PATH)!;
        return Utils.unescape(path) + "/" + parentController!.vmName.stringValue + "." + MacMulatorConstants.VM_EXTENSION;
    }
    
    fileprivate func computeDescription() -> String {
        let description = parentController?.vmDescription.string;
        if description != NewVMViewController.DESCRIPTION_DEFAULT_MESSAGE {
            return description!;
        }
        return "";
    }
}
