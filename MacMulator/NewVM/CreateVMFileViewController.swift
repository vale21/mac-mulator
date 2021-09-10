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
            let path = computePath();
            let displayName = parentController.vmName.stringValue;
            let description = computeDescription();
            let memory = Utils.getDefaultMemoryForSubType(os, subtype);
            let cpus = Utils.getCpusForSubType(os, subtype);
            let displayResolution = QemuConstants.RES_1280_768;
            
            let vm = VirtualMachine(os: os, subtype: subtype, architecture: architecture, path: path, displayName: displayName, description: description, memory: Int32(memory), cpus: cpus, displayResolution: displayResolution, qemuBootloader: false);
            
            let virtualHDD = setupVirtualDriveObjects(vm: vm, architecture: architecture, os: os, subtype: subtype, path: path)!;
            
            createDriveFilesOnDisk(vm: vm, virtualHDD: virtualHDD, path: path, displayName: displayName, architecture: architecture, os: os);
        }
    }
    
    fileprivate func setupVirtualDriveObjects(vm: VirtualMachine, architecture: String, os: String, subtype: String, path: String) -> VirtualDrive? {
        
        if let parentController = self.parentController {
            if architecture == QemuConstants.ARCH_ARM64 || architecture == QemuConstants.ARCH_X64 && os == QemuConstants.OS_MAC {
                let virtualEfi = VirtualDrive(
                    path: path + "/" + QemuConstants.MEDIATYPE_EFI + "-0." + MacMulatorConstants.EFI_EXTENSION,
                    name: QemuConstants.MEDIATYPE_EFI + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_EFI,
                    size: 0);
                vm.addVirtualDrive(virtualEfi)
            }
            if architecture == QemuConstants.ARCH_X64 && os == QemuConstants.OS_MAC {
                let openCore = VirtualDrive(
                    path: path + "/" + QemuConstants.MEDIATYPE_OPENCORE + "-0." + MacMulatorConstants.IMG_EXTENSION,
                    name: QemuConstants.MEDIATYPE_OPENCORE + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_OPENCORE,
                    size: 0);
                vm.addVirtualDrive(openCore);
            }
            
            let virtualHDD = VirtualDrive(
                path: path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION,
                name: QemuConstants.MEDIATYPE_DISK + "-0",
                format: QemuConstants.FORMAT_QCOW2,
                mediaType: QemuConstants.MEDIATYPE_DISK,
                size: Int32(Utils.getDefaultDiskSizeForSubType(os, subtype)));
            vm.addVirtualDrive(virtualHDD);
            
            if parentController.installMedia.stringValue != "" {
                if architecture == QemuConstants.ARCH_X64 && os == QemuConstants.OS_MAC {
                    // Install media is a USB stick
                    let virtualUSB = VirtualDrive(
                        path: parentController.installMedia.stringValue,
                        name: QemuConstants.MEDIATYPE_USB + "-0",
                        format: QemuConstants.FORMAT_RAW,
                        mediaType: QemuConstants.MEDIATYPE_USB,
                        size: 0);
                    virtualUSB.setBootDrive(true);
                    vm.addVirtualDrive(virtualUSB);
                } else {
                    // Install media is a CD
                    let virtualCD = VirtualDrive(
                        path: parentController.installMedia.stringValue,
                        name: QemuConstants.MEDIATYPE_CDROM + "-0",
                        format: QemuConstants.FORMAT_RAW,
                        mediaType: QemuConstants.MEDIATYPE_CDROM,
                        size: 0);
                    virtualCD.setBootDrive(true);
                    vm.addVirtualDrive(virtualCD);
                }
            }
            
            return virtualHDD;
        }
        
        return nil;
    }
    
    fileprivate func createDriveFilesOnDisk(vm: VirtualMachine, virtualHDD: VirtualDrive, path: String, displayName: String, architecture: String, os: String) {
        
        var complete = false;
        var created = false;
        
        do {
            try createDocumentPackage(path);
            QemuUtils.createDiskImage(path: path, virtualDrive: virtualHDD, uponCompletion: {
                terminationCcode in
                vm.writeToPlist(path + "/" + MacMulatorConstants.INFO_PLIST);
            });
        } catch {
            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                            message: "Unable to create Virtual Machine " + displayName + ": " + error.localizedDescription, completionHandler: {
                                response in
                                complete = true;
                                created = false;
                            });
        }
        
        DispatchQueue.global().async {
            do {
                if (architecture == QemuConstants.ARCH_ARM64) {
                    try FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "QEMU_EFI.fd", ofType: nil)!, toPath: path + "/efi-0.fd");
                }
                if (architecture == QemuConstants.ARCH_X64 && os == QemuConstants.OS_MAC) {
                    try FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "MACOS_EFI.fd", ofType: nil)!, toPath: path + "/efi-0.fd");
                    
                    let sourceURL = URL(fileURLWithPath: Bundle.main.path(forResource: "OPENCORE_MODERN.zip", ofType: nil)!);
                    let destinationURL = URL(fileURLWithPath: path);
                    try FileManager.default.unzipItem(at: sourceURL, to: destinationURL, skipCRC32: true);
                    
                    // Rename unzipped image and clean up garbage empty folder
                    try FileManager.default.moveItem(atPath: path + "/OPENCORE_MODERN.img", toPath: path + "/opencore-0.img");
                    try FileManager.default.removeItem(at: URL(fileURLWithPath: path + "/__MACOSX"));
                }
                complete = true;
                created = true;
            } catch {
                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                message: "Unable to create Virtual Machine " + displayName + ": " + error.localizedDescription, completionHandler: {
                                    response in
                                    complete = true;
                                    created = false;
                                });
            }
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
