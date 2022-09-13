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
    @IBOutlet weak var estimateTimeRemainingLabel: NSTextField!
    
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
            let networkDevice = Utils.getNetworkForSubType(os, subtype)
            
            let vm = VirtualMachine(os: os, subtype: subtype, architecture: architecture, path: path, displayName: displayName, description: description, memory: Int32(memory), cpus: cpus, displayResolution: displayResolution, networkDevice: networkDevice, qemuBootloader: false, hvf: Utils.getAccelForSubType(os, subtype));
            
            var foundError: Bool = false;
            
            let installMedia = parentController.installMedia.stringValue;
            if !Utils.isIpswInstallMediaProvided(installMedia) {
                progressBar.isIndeterminate = false
                progressBar.minValue = 0
                progressBar.maxValue = 100
                progressBar.doubleValue = 0.0
                descriptionLabel.stringValue = "Preparing to download macOS Installer..."
                estimateTimeRemainingLabel.stringValue = "Estimate time remaining: Calculating..."
            }
            
            let vmCreator: VMCreator = VMCreatorFactory().create(vm: vm);
            
            let startTime = Int64(Date().timeIntervalSince1970)
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in

                if !Utils.isIpswInstallMediaProvided(installMedia) {
                    let progress = vmCreator.getProgress()
                    self.progressBar.doubleValue = progress
                    let currentValue = self.progressBar.doubleValue
                    if (currentValue <= 0) {
                        self.descriptionLabel.stringValue = "Preparing to download macOS Installer..."
                        self.estimateTimeRemainingLabel.stringValue = "Estimate time remaining: Calculating..."
                    }  else {
                        self.descriptionLabel.stringValue = "Downloading macOS Installer (" + String(Int(progress)) + "%)..."
                        self.estimateTimeRemainingLabel.stringValue = "Estimate time remaining: " + Utils.computeTimeRemaining(startTime: startTime, progress: progress)
                    }
                }
                
                guard !vmCreator.isComplete() else {
                    self.creationComplete(timer, foundError, vm)
                    return;
                }
            });
            
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
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
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
