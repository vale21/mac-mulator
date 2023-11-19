//
//  QemuVMCreator.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation 
import ZIPFoundation

class QemuVMCreator: VMCreator {
    
    var complete = false
    var progress: Double = 0.0
    
    func createVM(vm: VirtualMachine, installMedia: String) throws {
        let virtualHDD = setupVirtualDriveObjects(vm: vm, installMedia: installMedia)!;
        try createDriveFilesOnDisk(vm: vm, virtualHDD: virtualHDD, installMedia: installMedia);
    }
    
    func isComplete() -> Bool {
        return complete;
    }
    
    func setProgress(_ progress: Double) {
        self.progress = progress
    }
    
    func getProgress() -> Double {
        return self.progress
    }
    
    func getError() -> Error? {
        return nil
    }
    
    func cancelVMCreation(vm: VirtualMachine) {
        
    }
    
    fileprivate func setupVirtualDriveObjects(vm: VirtualMachine, installMedia: String) -> VirtualDrive? {
                
        var virtualHDD: VirtualDrive? = nil
        if installMedia != "" {
            if vm.architecture == QemuConstants.ARCH_X64 && vm.os == QemuConstants.OS_MAC {
                // Install media is a USB stick
                let virtualUSB = VirtualDrive(
                    path: installMedia,
                    name: QemuConstants.MEDIATYPE_USB + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_USB,
                    size: 0);
                virtualUSB.isBootDrive = true
                vm.addVirtualDrive(virtualUSB);
            } else if Utils.isVHDXImage(installMedia) {
                // Install media is a VHDX drive. We create a VirtualDrive of type NVME
                virtualHDD = VirtualDrive(
                    path: vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION,
                    name: QemuConstants.MEDIATYPE_DISK + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_NVME,
                    size: 0); // Size is zero because we don't know it at this stage. We will upadte it after the conversion to qvd
                virtualHDD!.isBootDrive = true
                vm.addVirtualDrive(virtualHDD!);
            } else {
                // Install media is a CD
                let virtualCD = VirtualDrive(
                    path: installMedia,
                    name: QemuConstants.MEDIATYPE_CDROM + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_CDROM,
                    size: 0);
                virtualCD.isBootDrive = true
                vm.addVirtualDrive(virtualCD);
            }
        }
        
        if virtualHDD == nil {
            virtualHDD = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION,
                name: QemuConstants.MEDIATYPE_DISK + "-0",
                format: QemuConstants.FORMAT_QCOW2,
                mediaType: QemuConstants.MEDIATYPE_DISK,
                size: Int32(Utils.getDefaultDiskSizeForSubType(vm.os, vm.subtype)));
            vm.addVirtualDrive(virtualHDD!);
        }
        
        return virtualHDD! // Safe to do this because the virtualHDD object is created above, it was found nil
    }
        
    fileprivate func createDriveFilesOnDisk(vm: VirtualMachine, virtualHDD: VirtualDrive, installMedia: String) throws {
        do {
            try Utils.createDocumentPackage(vm.path);
            if !Utils.isVHDXImage(installMedia) {
                QemuUtils.createDiskImage(path: vm.path, virtualDrive: virtualHDD, uponCompletion: {
                    terminationCcode in
                    vm.writeToPlist(vm.path + "/" + MacMulatorConstants.INFO_PLIST);
                    QemuUtils.createAuxiliaryDriveFilesOnDisk(vm)
                    self.complete = true
                });
            } else {
                QemuUtils.convertVHDXToDiskImage(vhdxPath: installMedia, vmPath: vm.path, virtualDrive: virtualHDD, uponCompletion: {
                    terminationCode, driveSize in
                    virtualHDD.size = driveSize
                    vm.writeToPlist(vm.path + "/" + MacMulatorConstants.INFO_PLIST);
                    QemuUtils.createAuxiliaryDriveFilesOnDisk(vm)
                    self.complete = true
                })
            }
        } catch {
            complete = true;
            throw error;
        }
    }
}

