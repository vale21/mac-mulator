//
//  VirtualizationFrameworkVMCreator.swift
//  MacMulator
//
//  Created by Vale on 11/04/22.
//

import Foundation
import Virtualization

@available(macOS 12.0, *)
class VirtualizationFrameworkVMCreator : VMCreator {
    
    private var virtualMachineResponder: MacOSVirtualMachineDelegate?
    private var complete: Bool = false
    private var error: Error? = nil
    private var progress: Double = 0.0
    private var restoreImage: MacOSRestoreImage?
        
    func createVM(vm: VirtualMachine, installMedia: String) throws {
    
        try! Utils.createDocumentPackage(vm.path);
        if !shouldDownloadIpsw(vm, installMedia) {
            print("Install media specified. Installing...");
            self.createVM_int(vm: vm, installMedia: installMedia);
        } else {
            
            #if arch(arm64)
            
            print("Detected macOS with IPSW Not specified. Downloading...");
            self.restoreImage = MacOSRestoreImage(self, vm);
            restoreImage!.download {error in
                if error != nil {
                    self.error = error
                    
                    do {
                        try Utils.removeDocumentPackage(vm.path);
                    } catch {
                        print("Error while deleting" + vm.path + ": " + error.localizedDescription);
                    }
                    
                    self.complete = true
                } else {
                    self.createVM_int(vm: vm, installMedia: vm.path + "/" + VirtualizationFrameworkMacOSSupport.RESTORE_IMAGE_NAME);
                }
            }
            
            #endif
        }
    }
    
    func isComplete() -> Bool {
        return complete
    }
    
    func setProgress(_ progress: Double) {
        self.progress = progress
    }
    
    func getProgress() -> Double {
        return progress
    }
    
    func getError() -> Error? {
        return error
    }
    
    func cancelVMCreation(vm: VirtualMachine) {
        
        #if arch(arm64)
        
        if let restoreImage = self.restoreImage {
            restoreImage.cancelDownload()
            
            do {
                try Utils.removeDocumentPackage(vm.path);
            } catch {
                print("Error while deleting" + vm.path + ": " + error.localizedDescription);
            }
        }
        
        #endif
    }
    
    fileprivate func createVMFilesOnDisk(_ vm: VirtualMachine, _ installMediaPath: String, uponCompletion callback: @escaping (Int32) -> Void) throws {
        let virtualHDD = VirtualDrive(
            path: vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION,
            name: QemuConstants.MEDIATYPE_DISK + "-0",
            format: QemuConstants.FORMAT_RAW,
            mediaType: QemuConstants.MEDIATYPE_DISK,
            size: Int32(Utils.getDefaultDiskSizeForSubType(vm.os, vm.subtype)))
        vm.addVirtualDrive(virtualHDD);
        
        if Utils.isMacVMWithOSVirtualizationFramework(os: vm.os, subtype: vm.subtype) {
            let installMedia = VirtualDrive(
                path: installMediaPath,
                name: QemuConstants.MEDIATYPE_IPSW,
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_IPSW,
                size: 0)
            vm.addVirtualDrive(installMedia);
        } else if installMediaPath != ""{
            let installMedia = VirtualDrive(
                path: installMediaPath,
                name: QemuConstants.MEDIATYPE_USB + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_USB,
                size: 0)
            vm.addVirtualDrive(installMedia);
        }
        
        QemuUtils.createDiskImage(path: vm.path, virtualDrive: virtualHDD, uponCompletion: {
            terminationCcode in
            callback(0);
        });
    }
        
    fileprivate func createVM_int(vm: VirtualMachine, installMedia: String) {
        try! self.createVMFilesOnDisk(vm, installMedia, uponCompletion: {
            terminationCode in
            vm.writeToPlist(vm.path + "/" + MacMulatorConstants.INFO_PLIST);
            self.setupVirtualMachine(vm: vm, ipswURL: URL(fileURLWithPath: installMedia));
        });
    }
    
    fileprivate func setupVirtualMachine(vm: VirtualMachine, ipswURL: URL) {
        if (Utils.isMacVMWithOSVirtualizationFramework(os: vm.os, subtype: vm.subtype)) {
            
            #if arch(arm64)
            
            VZMacOSRestoreImage.load(from: ipswURL, completionHandler: { [self](result: Result<VZMacOSRestoreImage, Error>) in
                switch result {
                case let .failure(error):
                    fatalError(error.localizedDescription)
                    
                case let .success(restoreImage):
                    VirtualizationFrameworkMacOSSupport.createMacOSVirtualMachineData(vm: vm, restoreImage: restoreImage);
                    complete = true
                }
            })
            
            #endif
            
        } else {
            if #available(macOS 13.0, *) {
                VirtualizationFrameworkLinuxSupport.createLinuxVirtualMachineData(vm: vm)
            }
            complete = true
        }
    }
    
    fileprivate func shouldDownloadIpsw(_ vm: VirtualMachine, _ installMedia: String) -> Bool {
        return Utils.isMacVMWithOSVirtualizationFramework(os: vm.os, subtype: vm.subtype) && !Utils.isIpswInstallMediaProvided(installMedia)
    }

}
