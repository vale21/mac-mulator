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
    private var progress: Double = 0.0
        
    func createVM(vm: VirtualMachine, installMedia: String) throws {
    
        #if arch(arm64)
        
        try! Utils.createDocumentPackage(vm.path);
        if !shouldDownloadIpsw(vm, installMedia) {
            print("IPSW specified. Installing...");
            self.createVM(vm: vm, url: URL.init(fileURLWithPath: installMedia));
        } else {
            print("IPSW Not specified. Downloading...");
            let restoreImage = MacOSRestoreImage(self, vm);
            restoreImage.download {
                self.createVM(vm: vm, url: URL.init(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkUtils.RESTORE_IMAGE_NAME));
            }
        }
        
        #endif
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
    
    fileprivate func createVMFilesOnDisk(_ vm: VirtualMachine, _ ipswUrl: URL, uponCompletion callback: @escaping (Int32) -> Void) throws {
        let virtualHDD = VirtualDrive(
            path: vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION,
            name: QemuConstants.MEDIATYPE_DISK + "-0",
            format: QemuConstants.FORMAT_RAW,
            mediaType: QemuConstants.MEDIATYPE_DISK,
            size: Int32(Utils.getDefaultDiskSizeForSubType(vm.os, vm.subtype)))
        vm.addVirtualDrive(virtualHDD);
        
        let installMedia = VirtualDrive(
            path: ipswUrl.path,
            name: QemuConstants.MEDIATYPE_IPSW,
            format: QemuConstants.FORMAT_RAW,
            mediaType: QemuConstants.MEDIATYPE_IPSW,
            size: 0)
        vm.addVirtualDrive(installMedia);
        
        QemuUtils.createDiskImage(path: vm.path, virtualDrive: virtualHDD, uponCompletion: {
            terminationCcode in
            callback(0);
        });
    }
    
#if arch(arm64)
    
    fileprivate func createVM(vm: VirtualMachine, url: URL) {
        try! self.createVMFilesOnDisk(vm, url, uponCompletion: {
            terminationCode in
            vm.writeToPlist(vm.path + "/" + MacMulatorConstants.INFO_PLIST);
            self.setupVirtualMachine(vm: vm, ipswURL: url);
        });
    }
    
    fileprivate func setupVirtualMachine(vm: VirtualMachine, ipswURL: URL) {
        if (Utils.isMacVMWithOSVirtualizationFramework(os: vm.os, subtype: vm.subtype)) {
            VZMacOSRestoreImage.load(from: ipswURL, completionHandler: { [self](result: Result<VZMacOSRestoreImage, Error>) in
                switch result {
                case let .failure(error):
                    fatalError(error.localizedDescription)
                    
                case let .success(restoreImage):
                    VirtualizationFrameworkUtils.createVirtualMachineData(vm: vm, restoreImage: restoreImage);
                    complete = true
                }
            })
        } else {
            complete = true
        }
    }
    
    fileprivate func shouldDownloadIpsw(_ vm: VirtualMachine, _ installMedia: String) -> Bool {
        return Utils.isMacVMWithOSVirtualizationFramework(os: vm.os, subtype: vm.subtype) && !Utils.isIpswInstallMediaProvided(installMedia)
    }
    
#endif
}
