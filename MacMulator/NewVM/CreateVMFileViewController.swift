//
//  CreateVMFileViewController.swift
//  MacMulator
//
//  Created by Vale on 21/04/21.
//

import Cocoa

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
            let path = computePath();
            let displayName = parentController.vmName.stringValue;
            let description = computeDescription();
            let memory = Utils.getDefaultMemoryForSubType(os, subtype);
            let cpus = Utils.getCpusForSubType(os, subtype);
            let displayResolution = QemuConstants.RES_1280_768;
            
            let vm = VirtualMachine(os: os, subtype: subtype, architecture: architecture, path: path, displayName: displayName, description: description, memory: Int32(memory), cpus: cpus, displayResolution: displayResolution, qemuBootloader: false);
            
            if (architecture == QemuConstants.ARCH_ARM64) {
                let virtualEfi = VirtualDrive(
                    path: path + "/" + QemuConstants.MEDIATYPE_EFI + "-0." + MacMulatorConstants.EFI_EXTENSION,
                    name: QemuConstants.MEDIATYPE_EFI + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_EFI,
                    size: 0);
                vm.addVirtualDrive(virtualEfi)
            }
            
            let virtualHDD = VirtualDrive(
                path: path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION,
                name: QemuConstants.MEDIATYPE_DISK + "-0",
                format: QemuConstants.FORMAT_QCOW2,
                mediaType: QemuConstants.MEDIATYPE_DISK,
                size: Int32(Utils.getDefaultDiskSizeForSubType(os, subtype)));
            vm.addVirtualDrive(virtualHDD);
                                    
            if parentController.installMedia.stringValue != "" {
                let virtualCD = VirtualDrive(
                    path: parentController.installMedia.stringValue,
                    name: QemuConstants.MEDIATYPE_CDROM + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_CDROM,
                    size: 0);
                virtualCD.setBootDrive(true);
                vm.addVirtualDrive(virtualCD);
            } 
            
            var complete = false;
            var created = false;
            
            do {
                try createDocumentPackage(path);
                QemuUtils.createDiskImage(path: path, virtualDrive: virtualHDD, uponCompletion: {
                    terminationCcode in 
                    vm.writeToPlist(path + "/" + MacMulatorConstants.INFO_PLIST);
                    complete = true;
                    created = true;
                });
                if (architecture == QemuConstants.ARCH_ARM64) {
                    try FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "QEMU_EFI.fd", ofType: nil)!, toPath: path + "/efi-0.fd");
                }
                
            } catch {
                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                message: "Unable to create Virtual Machine " + displayName + ": " + error.localizedDescription, completionHandler: {
                                    response in
                                    complete = true;
                                    created = false;
                                })
            }
            
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
                
                guard !complete else {
                    timer.invalidate();
                    self.progressBar.stopAnimation(self);
                    self.dismiss(self);
                    
                    if created {
                        self.parentController!.vmCreated(vm);
                    }
                    return;
                }
            });
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

    fileprivate func createDocumentPackage(_ path: String) throws {
        let fileManager = FileManager.default;
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil);
    }
}
