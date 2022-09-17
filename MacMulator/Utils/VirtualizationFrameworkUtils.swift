//
//  VirtualizationFrameworkConstants.swift
//  MacMulator
//
//  Created by Vale on 17/09/22.
//

import Foundation
import Virtualization

@available(macOS 12.0, *)
class VirtualizationFrameworkUtils {
    
    static let RESTORE_IMAGE_NAME = "macos-restore-image.ipsw"
    static let AUXILIARY_STORAGE_NAME = "auxiliary-storage"
    static let MACHINE_IDENTIFIER_NAME = "machine-identifier"
    static let HARDWARE_MODEL_NAME = "hardware-model"
    

    static func setupVirtualMachine(vm: VirtualMachine, restoreImage: VZMacOSRestoreImage) {
        
        guard let macOSConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            fatalError("No supported configuration available.")
        }
        
        if !macOSConfiguration.hardwareModel.isSupported {
            fatalError("macOSConfiguration configuration is not supported on the current host.")
        }
        
        setupVirtualMachine(vm: vm, macOSConfiguration: macOSConfiguration)
    }
    

    fileprivate static func setupVirtualMachine(vm: VirtualMachine, macOSConfiguration: VZMacOSConfigurationRequirements) {
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
    }
    
    fileprivate static func createMacPlatformConfiguration(vm: VirtualMachine, macOSConfiguration: VZMacOSConfigurationRequirements) -> VZMacPlatformConfiguration {
        let macPlatformConfiguration = VZMacPlatformConfiguration()
        let auxiliaryStorageURL = URL(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkUtils.AUXILIARY_STORAGE_NAME + "-0")
        let machineIdentifierURL = URL(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkUtils.MACHINE_IDENTIFIER_NAME + "-0")
        let hardwareModelURL = URL(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkUtils.HARDWARE_MODEL_NAME + "-0")
        
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
}
