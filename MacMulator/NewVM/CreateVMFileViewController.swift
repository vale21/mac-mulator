//
//  CreateVMFileViewController.swift
//  MacMulator
//
//  Created by Vale on 21/04/21.
//

import Cocoa
import ZIPFoundation
import Virtualization

class CreateVMFileViewController : NSViewController {
    
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var estimateTimeRemainingLabel: NSTextField!
    @IBOutlet weak var cancelButton: NSButton!
    
    private var parentController: NewVMViewController?
    private var vmCreator: VMCreator?
    private var timer: Timer?
    private var vm: VirtualMachine?
    
    func setParentController(_ parentController: NewVMViewController) {
        self.parentController = parentController;
    }
    
    override func viewDidAppear() {
        progressBar.startAnimation(self);
        
        if let parentController = self.parentController {
            let os = parentController.vmType.stringValue
            let subtype = parentController.vmSubType.stringValue
            let architecture = Utils.getArchitectureForSubType(os, subtype)
            let path = Utils.computeVMPath(vmName: parentController.vmName.stringValue)
            let displayName = parentController.vmName.stringValue
            let description = computeDescription()
            let memory = Utils.getDefaultMemoryForSubType(os, subtype)
            let cpus = Utils.getCpusForSubType(os, subtype)
            let displayResolution = QemuConstants.RES_1280_768
            let displayOrigin = QemuConstants.ORIGIN
            let networkDevice = Utils.getNetworkForSubType(os, subtype)
            let hvf = Utils.getAccelForSubType(os, subtype)
            let vmType = VMCreatorFactory().getVMType(os: os, subtype: subtype, architecture: architecture)
            
            var macAddress: String? = nil
            if #available(macOS 11.0, *) {
                macAddress = VZMACAddress.randomLocallyAdministered().string
            }
            self.vm = VirtualMachine(os: os, subtype: subtype, architecture: architecture, path: path, displayName: displayName, description: description, memory: Int32(memory), cpus: cpus, displayResolution: displayResolution, displayOrigin: displayOrigin, networkDevice: networkDevice, qemuBootloader: false, hvf: hvf, macAddress: macAddress, type: vmType);
            
            if let vm = self.vm {
                let installMedia = parentController.installMedia.stringValue;
                if shouldDownloadIpsw(vm, installMedia) {
                    // Downloading IPSW
                    progressBar.isIndeterminate = false
                    progressBar.minValue = 0
                    progressBar.maxValue = 100
                    progressBar.doubleValue = 0.0
                    descriptionLabel.stringValue = "Preparing to download macOS Installer..."
                    estimateTimeRemainingLabel.stringValue = "Estimate time remaining: Calculating..."
                    cancelButton.isHidden = false
                } else {
                    descriptionLabel.stringValue = "Creating Virtual Machine..."
                    estimateTimeRemainingLabel.isHidden = true
                    cancelButton.isHidden = true
                    
                    let currentFrame = self.view.window?.frame
                    let size = CGSize(width: currentFrame!.width - 25, height: currentFrame!.height - 25)
                    self.view.window?.setContentSize(size)
                }
                
                
                self.vmCreator = VMCreatorFactory().create(vm: vm);
                
                let startTime = Int64(Date().timeIntervalSince1970)
                var error: Error? = nil
                
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { timer in
                    
                    if self.shouldDownloadIpsw(vm, installMedia) {
                        let progress = self.vmCreator!.getProgress()
                        error = self.vmCreator?.getError()
                        
                        self.progressBar.doubleValue = progress
                        let currentValue = self.progressBar.doubleValue
                        if (currentValue <= 0) {
                            self.descriptionLabel.stringValue = "Preparing to download macOS Installer..."
                            self.estimateTimeRemainingLabel.stringValue = "Estimate time remaining: Calculating..."
                        } else if (currentValue < 10) {
                            self.descriptionLabel.stringValue = "Downloading macOS Installer (" + String(Int(progress)) + "%)..."
                            self.estimateTimeRemainingLabel.stringValue = "Estimate time remaining: Calculating..."
                        } else if (currentValue < 100) {
                            self.descriptionLabel.stringValue = "Downloading macOS Installer (" + String(Int(progress)) + "%)..."
                            self.estimateTimeRemainingLabel.stringValue = "Estimate time remaining: " + Utils.computeTimeRemaining(startTime: startTime, progress: progress)
                        } else {
                            self.descriptionLabel.stringValue = "Creating Virtual Machine..."
                        }
                    }
                    
                    guard !self.vmCreator!.isComplete() else {
                        self.creationComplete(timer, error, vm)
                        return;
                    }
                });
                
                DispatchQueue.global().async {
                    do {
                        try self.vmCreator!.createVM(vm: vm, installMedia: installMedia);
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
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        if let vmCreator = self.vmCreator {
            if let vm = self.vm {
                vmCreator.cancelVMCreation(vm: vm)
            }
            
            if let timer = self.timer {
                timer.invalidate();
            }
            
            self.progressBar.stopAnimation(self);
            self.dismiss(self);
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
    
    fileprivate func creationComplete(_ timer: Timer, _ error: Error?, _ vm: VirtualMachine) {
        timer.invalidate();
        self.progressBar.stopAnimation(self);
        self.dismiss(self);
        
        if error == nil {
            self.parentController!.vmCreated(vm)
        } else {
            self.parentController!.vmCreationfFailed(vm, error!)
        }
    }
    
    fileprivate func shouldDownloadIpsw(_ vm: VirtualMachine, _ installMedia: String) -> Bool {
        return Utils.isMacVMWithOSVirtualizationFramework(os: vm.os, subtype: vm.subtype) && !Utils.isIpswInstallMediaProvided(installMedia)
    }
}
