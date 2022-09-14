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
    var parentController: NewVMViewController?;
    
    func setParentController(_ parentController: NewVMViewController) {
        self.parentController = parentController;
    }
    
    override func viewDidAppear() {
        progressBar.startAnimation(self);
        
        if let parentController = self.parentController {
            let os = parentController.vmType.stringValue;
            let subtype = parentController.vmSubType.stringValue;
            let architecture = Utils.getArchitectureForSubType(os, subtype);
            let path = Utils.computeVMPath(vmName: parentController.vmName.stringValue)
            let displayName = parentController.vmName.stringValue;
            let description = computeDescription();
            let memory = Utils.getDefaultMemoryForSubType(os, subtype);
            let cpus = Utils.getCpusForSubType(os, subtype);
            let displayResolution = QemuConstants.RES_1280_768;
            let networkDevice = Utils.getNetworkForSubType(os, subtype)
            
            let vm = VirtualMachine(os: os, subtype: subtype, architecture: architecture, path: path, displayName: displayName, description: description, memory: Int32(memory), cpus: cpus, displayResolution: displayResolution, networkDevice: networkDevice, qemuBootloader: false, hvf: Utils.getAccelForSubType(os, subtype));
            
            if let parentController = self.parentController {
                
                let vmCreator: VMCreator = VMCreatorFactory().create(vm: vm);
                
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
                    
                    guard !vmCreator.isComplete() else {
                        timer.invalidate();
                        self.progressBar.stopAnimation(self);
                        self.dismiss(self);
                        
                        if vmCreator.isCreated() {
                            self.parentController!.vmCreated(vm);
                        }
                        return;
                    }
                });
                
                let installMedia = parentController.installMedia.stringValue;
                DispatchQueue.global().async {
                    do {
                        try vmCreator.createVM(vm: vm, installMedia: installMedia);
                    } catch {
                        DispatchQueue.main.async {
                            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                            message: "Unable to create Virtual Machine " + vm.displayName + ": " + error.localizedDescription);
                        }
                    }
                }
            }
        }
    }
        
    fileprivate func computeDescription() -> String {
        let description = parentController?.vmDescription.string;
        if description != NewVMViewController.DESCRIPTION_DEFAULT_MESSAGE {
            return description!;
        }
        return "";
    }
}
