//
//  QemuVMCreator.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation 
import ZIPFoundation

class QemuVMCreator: VMCreator {
    
    var complete = false;

    func createVM(vm: VirtualMachine, installMedia: String) throws {
        let virtualHDD = setupVirtualDriveObjects(vm: vm, installMedia: installMedia)!;
        try createDriveFilesOnDisk(vm: vm, virtualHDD: virtualHDD);
    }
    
    func isComplete() -> Bool {
        return complete;
    }
    
    fileprivate func setupVirtualDriveObjects(vm: VirtualMachine, installMedia: String) -> VirtualDrive? {
        
        if vm.architecture == QemuConstants.ARCH_ARM64 || vm.architecture == QemuConstants.ARCH_X64 && vm.os == QemuConstants.OS_MAC {
            let virtualEfi = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_EFI + "-0." + MacMulatorConstants.EFI_EXTENSION,
                name: QemuConstants.MEDIATYPE_EFI + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_EFI,
                size: 0);
            vm.addVirtualDrive(virtualEfi)
        }
        
        if vm.architecture == QemuConstants.ARCH_X64 && vm.os == QemuConstants.OS_MAC {
            let openCore = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_OPENCORE + "-0." + MacMulatorConstants.IMG_EXTENSION,
                name: QemuConstants.MEDIATYPE_OPENCORE + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_OPENCORE,
                size: 0);
            vm.addVirtualDrive(openCore);
        }
        
        let virtualHDD = VirtualDrive(
            path: vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION,
            name: QemuConstants.MEDIATYPE_DISK + "-0",
            format: QemuConstants.FORMAT_QCOW2,
            mediaType: QemuConstants.MEDIATYPE_DISK,
            size: Int32(Utils.getDefaultDiskSizeForSubType(vm.os, vm.subtype)));
        vm.addVirtualDrive(virtualHDD);
        
        if installMedia != "" {
            if vm.architecture == QemuConstants.ARCH_X64 && vm.os == QemuConstants.OS_MAC {
                // Install media is a USB stick
                let virtualUSB = VirtualDrive(
                    path: installMedia,
                    name: QemuConstants.MEDIATYPE_USB + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_USB,
                    size: 0);
                virtualUSB.setBootDrive(true);
                vm.addVirtualDrive(virtualUSB);
            } else {
                // Install media is a CD
                let virtualCD = VirtualDrive(
                    path: installMedia,
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
    
    fileprivate func createDriveFilesOnDisk(vm: VirtualMachine, virtualHDD: VirtualDrive) throws {
        
        do {
            try Utils.createDocumentPackage(vm.path);
            QemuUtils.createDiskImage(path: vm.path, virtualDrive: virtualHDD, uponCompletion: {
                terminationCcode in
                vm.writeToPlist(vm.path + "/" + MacMulatorConstants.INFO_PLIST);
            });
        } catch {
            complete = true;
            throw error;
        }
        
        do {
            if (vm.architecture == QemuConstants.ARCH_ARM64) {
                try FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "QEMU_EFI.fd", ofType: nil)!, toPath: vm.path + "/efi-0.fd");
            }
            if (vm.architecture == QemuConstants.ARCH_X64 && vm.os == QemuConstants.OS_MAC) {
                var opencore: String = "";
                if QemuUtils.isMacModern(vm.subtype) {
                    opencore = QemuConstants.OPENCORE_MODERN;
                } else if QemuUtils.isMacLegacy(vm.subtype) {
                    opencore = QemuConstants.OPENCORE_LEGACY;
                }
                
                try FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "MACOS_EFI.fd", ofType: nil)!, toPath: vm.path + "/efi-0.fd");
                
                let sourceURL = URL(fileURLWithPath: Bundle.main.path(forResource: opencore + ".zip", ofType: nil)!);
                let destinationURL = URL(fileURLWithPath: vm.path);
                try FileManager.default.unzipItem(at: sourceURL, to: destinationURL, skipCRC32: true);
                
                // Rename unzipped image and clean up garbage empty folder
                try FileManager.default.moveItem(atPath: vm.path + "/" + opencore + ".img", toPath: vm.path + "/opencore-0.img");
                try FileManager.default.removeItem(at: URL(fileURLWithPath: vm.path + "/__MACOSX"));
            }
            self.complete = true;
        } catch {
            self.complete = true;
            throw error;
        }
    }
    

}

