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
            let architecture = computeArchitecture(os);
            let path = computePath();
            let displayName = parentController.vmName.stringValue;
            let description = computeDescription();
            let memory = computeMemory(os);
            let displayResolution = QemuConstants.RES_1280_800;
            
            let vm = VirtualMachine(os: os, architecture: architecture, path: path, displayName: displayName, description: description, memory: memory, displayResolution: displayResolution, qemuBootloader: false);
            
            let virtualHDD = VirtualDrive(
                path: path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION,
                name: QemuConstants.MEDIATYPE_DISK + "-0",
                format: QemuConstants.FORMAT_QCOW2,
                mediaType: QemuConstants.MEDIATYPE_DISK,
                size: 256);
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
            do {
                let tempPath = NSTemporaryDirectory() + displayName + "." + MacMulatorConstants.VM_EXTENSION;
                
                try createDocumentPackage(tempPath);
                QemuUtils.createDiskImage(path: tempPath, virtualDrive: virtualHDD, uponCompletion: {
                    vm.writeToPlist(tempPath + "/" + MacMulatorConstants.INFO_PLIST);
                    
                    let moveCommand = "mv " + Utils.escape(tempPath) + " " + path;
                    
                    Shell().runCommand(moveCommand, uponCompletion: {
                        complete = true;
                    });
                });
            } catch {
                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                message: "Unable to create Virtual Machine " + displayName + ": " + error.localizedDescription);
            }
            
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
            
                guard !complete else {
                    timer.invalidate();
                    self.progressBar.stopAnimation(self);
                    self.dismiss(self);
                    
                    self.parentController!.vmCreated(vm);
                    return;
                }
            });
        }
    }
    
    fileprivate func computeArchitecture(_ type: String) -> String {
        if type == QemuConstants.OS_MAC {
            return QemuConstants.ARCH_PPC;
        }
        return QemuConstants.ARCH_X64;
    }
    
    fileprivate func computePath() -> String {
        let userDefaults = UserDefaults.standard;
        let path = userDefaults.value(forKey: "libraryPath") as! String;
        return path + "/" + parentController!.vmName.stringValue + "." + MacMulatorConstants.VM_EXTENSION;
    }
    
    fileprivate func computeDescription() -> String? {
        let description = parentController?.vmDescription.string;
        if description != NewVMViewController.DESCRIPTION_DEFAULT_MESSAGE {
            return description;
        }
        return nil;
    }
    
    fileprivate func computeMemory(_ type: String) -> Int32 {
        if type == QemuConstants.OS_MAC {
            return 1024;
        }
        return 2048;
    }
    
    fileprivate func createDocumentPackage(_ path: String) throws {
        let fileManager = FileManager.default;
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil);
    }
}
