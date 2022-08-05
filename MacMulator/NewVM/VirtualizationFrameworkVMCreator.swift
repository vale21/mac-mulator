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
    private var progress: Double = 0.0
        
    func createVM(vm: VirtualMachine, installMedia: String) throws {
#if arch(arm64)
        
        try! Utils.createDocumentPackage(vm.path);
        if Utils.isIpswInstallMediaProvided(installMedia) {
            print("IPSW specified. Installing...");
            self.installFromIPSW(vm: vm, url: URL.init(fileURLWithPath: installMedia));
        } else {
            print("IPSW Not specified. Downloading...");
            let restoreImage = MacOSRestoreImage();
            restoreImage.download(path: vm.path) {
                url in
                self.installFromIPSW(vm: vm, url: url);
            }
        }
#endif
    }
    
    func isComplete() -> Bool {
        return progress >= 100.0;
    }
    
    func creationProgress() -> Double {
        return progress
    }
    
    fileprivate func createVMFilesOnDisk(_ vm: VirtualMachine, uponCompletion callback: @escaping (Int32) -> Void) throws {
        let virtualHDD = VirtualDrive(
            path: vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION,
            name: QemuConstants.MEDIATYPE_DISK + "-0",
            format: QemuConstants.FORMAT_RAW,
            mediaType: QemuConstants.MEDIATYPE_DISK,
            size: Int32(Utils.getDefaultDiskSizeForSubType(vm.os, vm.subtype)));
        vm.addVirtualDrive(virtualHDD);
        
        QemuUtils.createDiskImage(path: vm.path, virtualDrive: virtualHDD, uponCompletion: {
            terminationCcode in
            callback(0);
        });
    }
    
#if arch(arm64)
    
    fileprivate func installFromIPSW(vm: VirtualMachine, url: URL) {
        try! self.createVMFilesOnDisk(vm, uponCompletion: {
            terminationCode in
            vm.writeToPlist(vm.path + "/" + MacMulatorConstants.INFO_PLIST);
            self.installOS(vm: vm, ipswURL: url);
        });
    }
    
    fileprivate func installOS(vm: VirtualMachine, ipswURL: URL) {
        print("Attempting to install from IPSW at \(ipswURL).")
        VZMacOSRestoreImage.load(from: ipswURL, completionHandler: { [self](result: Result<VZMacOSRestoreImage, Error>) in
            switch result {
            case let .failure(error):
                fatalError(error.localizedDescription)
                
            case let .success(restoreImage):
                installOS(vm: vm, restoreImage: restoreImage);
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
        virtualMachineConfiguration.cpuCount = vm.cpus;
        virtualMachineConfiguration.memorySize = UInt64(vm.memory) * (1024 * 1024);
        virtualMachineConfiguration.bootLoader = MacOSVirtualMachineConfigurationHelper.createBootLoader()
        
        let resolution = Utils.getResolutionElements(vm.displayResolution)
        if let mainScreen = NSScreen.main {
            virtualMachineConfiguration.graphicsDevices = [MacOSVirtualMachineConfigurationHelper.createGraphicsDeviceConfiguration(
                witdh: Int(mainScreen.backingScaleFactor * CGFloat(resolution[0])),
                height: Int(mainScreen.backingScaleFactor * CGFloat(resolution[1])),
                ppi: Int(mainScreen.backingScaleFactor * 110))]
        } else {
            virtualMachineConfiguration.graphicsDevices = [MacOSVirtualMachineConfigurationHelper.createGraphicsDeviceConfiguration(
                witdh: resolution[0],
                height: resolution[1],
                ppi: 110)]
        }
        
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
        
        guard let auxiliaryStorage = try? VZMacAuxiliaryStorage(creatingStorageAt: auxiliaryStorageURL, hardwareModel: macOSConfiguration.hardwareModel, options: [])
        else {
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
            
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
                
                _ = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
                    self.progress = change.newValue! * 100
                    print("Installation progress: \(self.progress).")
                }
                
                guard !self.isComplete() else {
                    timer.invalidate();
                    return;
                }
            });
        }
    }
    
    
#endif
}
