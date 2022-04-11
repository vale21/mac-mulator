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
    
    var complete = false;
            
    func createVM(vm: VirtualMachine, installMedia: String) throws {
        #if arch(arm64)
        
        do {
            try Utils.createDocumentPackage(vm.path);
            let restoreImage = MacOSRestoreImage();
            restoreImage.download(path: vm.path) {
                url in
                do {
                    try self.createVMFilesOnDisk(vm);
                    self.installOS(vm: vm, ipswURL: url);
                } catch {}
            }
        } catch {}
        
        #endif
    }
    
    func isComplete() -> Bool {
        return complete;
    }
    
    fileprivate func createVMFilesOnDisk(_ vm: VirtualMachine) throws {
        do {
            let virtualHDD = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION,
                name: QemuConstants.MEDIATYPE_DISK + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_DISK,
                size: Int32(Utils.getDefaultDiskSizeForSubType(vm.os, vm.subtype)));
            vm.addVirtualDrive(virtualHDD);
            
            do {
                QemuUtils.createDiskImage(path: vm.path, virtualDrive: virtualHDD, uponCompletion: {
                    terminationCcode in
                    vm.writeToPlist(vm.path + "/" + MacMulatorConstants.INFO_PLIST);
                });
            } catch {
                complete = true;
                throw error;
            }
            
            complete = true;
        } catch {
            complete = true;
            throw error;
        }
    }
    
    #if arch(arm64)
    
    fileprivate func installOS(vm: VirtualMachine, ipswURL: URL) {
        print("Attempting to install from IPSW at \(ipswURL).")
        VZMacOSRestoreImage.load(from: ipswURL, completionHandler: { [self](result: Result<VZMacOSRestoreImage, Error>) in
            switch result {
                case let .failure(error):
                    fatalError(error.localizedDescription)

                case let .success(restoreImage):
                installOS(vm: vm, restoreImage: restoreImage)
            }
        })
    }
    
    fileprivate func installOS(vm: VirtualMachine, restoreImage: VZMacOSRestoreImage) {
        guard let macOSConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            fatalError("No supported configuration available.")
        }

        if !macOSConfiguration.hardwareModel.isSupported {
            fatalError("macOSConfiguration configuration is not supported on the current host.")
        }

        let virtualMachine: VZVirtualMachine = setupVirtualMachine(vm: vm, macOSConfiguration: macOSConfiguration)
        startInstallation(virtualMachine: virtualMachine, restoreImageURL: restoreImage.url)
    }
    
    // MARK: Create the Virtual Machine Configuration and instantiate the Virtual Machine

    fileprivate func setupVirtualMachine(vm: VirtualMachine, macOSConfiguration: VZMacOSConfigurationRequirements) -> VZVirtualMachine {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()

        virtualMachineConfiguration.platform = createMacPlatformConfiguration(vm: vm, macOSConfiguration: macOSConfiguration)
        virtualMachineConfiguration.cpuCount = MacOSVirtualMachineConfigurationHelper.computeCPUCount()
        if virtualMachineConfiguration.cpuCount < macOSConfiguration.minimumSupportedCPUCount {
            fatalError("CPUCount is not supported by the macOS configuration.")
        }

        virtualMachineConfiguration.memorySize = MacOSVirtualMachineConfigurationHelper.computeMemorySize()
        if virtualMachineConfiguration.memorySize < macOSConfiguration.minimumSupportedMemorySize {
            fatalError("memorySize is not supported by the macOS configuration.")
        }

        virtualMachineConfiguration.bootLoader = MacOSVirtualMachineConfigurationHelper.createBootLoader()
        virtualMachineConfiguration.graphicsDevices = [MacOSVirtualMachineConfigurationHelper.createGraphicsDeviceConfiguration()]
        virtualMachineConfiguration.storageDevices = [MacOSVirtualMachineConfigurationHelper.createBlockDeviceConfiguration(path: vm.drives[0].path)]
        virtualMachineConfiguration.networkDevices = [MacOSVirtualMachineConfigurationHelper.createNetworkDeviceConfiguration()]
        virtualMachineConfiguration.pointingDevices = [MacOSVirtualMachineConfigurationHelper.createPointingDeviceConfiguration()]
        virtualMachineConfiguration.keyboards = [MacOSVirtualMachineConfigurationHelper.createKeyboardConfiguration()]
        virtualMachineConfiguration.audioDevices = [MacOSVirtualMachineConfigurationHelper.createAudioDeviceConfiguration()]

        try! virtualMachineConfiguration.validate()

        let virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration)
        return virtualMachine;
    }
    
    fileprivate func createMacPlatformConfiguration(vm: VirtualMachine, macOSConfiguration: VZMacOSConfigurationRequirements) -> VZMacPlatformConfiguration {
        let macPlatformConfiguration = VZMacPlatformConfiguration()
        let auxiliaryStorageURL = URL(fileURLWithPath: vm.path + "/AuxiliaryStorage")
        let machineIdentifierURL = URL(fileURLWithPath: vm.path + "/MachineIdentifier")
        let hardwareModelURL = URL(fileURLWithPath: vm.path + "/HardwareModel")

        guard let auxiliaryStorage = try? VZMacAuxiliaryStorage(creatingStorageAt: auxiliaryStorageURL,
                                                                    hardwareModel: macOSConfiguration.hardwareModel,
                                                                          options: []) else {
            fatalError("Failed to create auxiliary storage.")
        }
        macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage
        macPlatformConfiguration.hardwareModel = macOSConfiguration.hardwareModel
        macPlatformConfiguration.machineIdentifier = VZMacMachineIdentifier()

        // Store the hardware model and machine identifier to disk so that we can retrieve them for subsequent boots.
        try! macPlatformConfiguration.hardwareModel.dataRepresentation.write(to: hardwareModelURL)
        try! macPlatformConfiguration.machineIdentifier.dataRepresentation.write(to: machineIdentifierURL)

        return macPlatformConfiguration
    }

    // MARK: Begin macOS installation

    fileprivate func startInstallation(virtualMachine: VZVirtualMachine, restoreImageURL: URL) {
        DispatchQueue.main.async {
            let installer = VZMacOSInstaller(virtualMachine: virtualMachine, restoringFromImageAt: restoreImageURL)

            print("Starting installation.")
            installer.install(completionHandler: { (result: Result<Void, Error>) in
                if case let .failure(error) = result {
                    fatalError(error.localizedDescription)
                } else {
                    print("Installation succeeded.")
                }
            })

            // Observe installation progress
            _ = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
                print("Installation progress: \(change.newValue! * 100).")
            }
        }
    }
    
    #endif
}
