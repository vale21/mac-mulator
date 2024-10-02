//
//  VirtualizationFrameworkConstants.swift
//  MacMulator
//
//  Created by Vale on 17/09/22.
//

import Foundation
import Virtualization

@available(macOS 12.0, *)
class VirtualizationFrameworkMacOSSupport : VirtualizationFrameworkSupport {

#if arch(arm64)
    
    static func createMacOSVirtualMachineData(vm: VirtualMachine, restoreImage: VZMacOSRestoreImage) {
        
        guard let macOSConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            fatalError("No supported configuration available.")
        }
        
        if !macOSConfiguration.hardwareModel.isSupported {
            fatalError("macOSConfiguration configuration is not supported on the current host.")
        }
        
        _ = createMacPlatformConfiguration(vm: vm, macOSConfiguration: macOSConfiguration)
    }
    
    static func decodeMacOSVirtualMachine(vm: VirtualMachine) -> VZVirtualMachine {
        let configuration = setupMacOSVirtualMachine(vm: vm)
        
        let virtualMachine = VZVirtualMachine(configuration: configuration, queue: .main)
        return virtualMachine;
    }
    
    fileprivate static func setupMacOSVirtualMachine(vm: VirtualMachine) -> VZVirtualMachineConfiguration {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()
        virtualMachineConfiguration.platform = createMacPlatformConfiguration(vm: vm, macOSConfiguration: nil)
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
        
        virtualMachineConfiguration.storageDevices = [MacOSVirtualMachineConfigurationHelper.createBlockDeviceConfiguration(path: Utils.findMainDrive(vm.drives)!.path)]
        if let macAddress = vm.macAddress {
            virtualMachineConfiguration.networkDevices = [MacOSVirtualMachineConfigurationHelper.createNetworkDeviceConfiguration(macAddress: macAddress)]
        } else {
            virtualMachineConfiguration.networkDevices = [MacOSVirtualMachineConfigurationHelper.createNetworkDeviceConfiguration(macAddress: VZMACAddress.randomLocallyAdministered().string)]
        }
        virtualMachineConfiguration.pointingDevices = MacOSVirtualMachineConfigurationHelper.createPointingDeviceConfigurations(vm: vm)
        virtualMachineConfiguration.keyboards = [MacOSVirtualMachineConfigurationHelper.createKeyboardConfiguration(vm: vm)]
        virtualMachineConfiguration.audioDevices = [MacOSVirtualMachineConfigurationHelper.createAudioDeviceConfiguration()]
        
        if #available(macOS 15.0, *) {
            virtualMachineConfiguration.usbControllers = [MacOSVirtualMachineConfigurationHelper.createUSBControllerConfiguration()]
        }
        
        try! virtualMachineConfiguration.validate()
        if #available(macOS 14.0, *) {
            do {
                try virtualMachineConfiguration.validateSaveRestoreSupport()
                vm.pauseSupported = true
            } catch {
                vm.pauseSupported = false
            }
        }
        
        return virtualMachineConfiguration
    }
    
    fileprivate static func createMacPlatformConfiguration(vm: VirtualMachine, macOSConfiguration: VZMacOSConfigurationRequirements?) -> VZMacPlatformConfiguration {
        let macPlatformConfiguration = VZMacPlatformConfiguration()
        let auxiliaryStorageURL = URL(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkMacOSSupport.AUXILIARY_STORAGE_NAME + "-0")
        let machineIdentifierURL = URL(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkMacOSSupport.MACHINE_IDENTIFIER_NAME + "-0")
        let hardwareModelURL = URL(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkMacOSSupport.HARDWARE_MODEL_NAME + "-0")
        
        if macOSConfiguration != nil {
            // Create resources using provided configuration
            
            guard let auxiliaryStorage = try? VZMacAuxiliaryStorage(creatingStorageAt: auxiliaryStorageURL, hardwareModel: macOSConfiguration!.hardwareModel, options: []) else {
                fatalError("Failed to create auxiliary storage.")
            }
            
            macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage
            macPlatformConfiguration.hardwareModel = macOSConfiguration!.hardwareModel
            macPlatformConfiguration.machineIdentifier = VZMacMachineIdentifier()
            
            // Store the hardware model and machine identifier to disk so that we can retrieve them for subsequent boots.
            try! macPlatformConfiguration.hardwareModel.dataRepresentation.write(to: hardwareModelURL)
            try! macPlatformConfiguration.machineIdentifier.dataRepresentation.write(to: machineIdentifierURL)
        } else {
            // Decode resources from bundle
            
            let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: auxiliaryStorageURL)
            macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage
            
            guard let hardwareModelData = try? Data(contentsOf: hardwareModelURL) else {
                fatalError("Failed to retrieve hardware model data.")
            }
            guard let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData) else {
                fatalError("Failed to create hardware model.")
            }
            macPlatformConfiguration.hardwareModel = hardwareModel;
            
            
            guard let machineIdentifierData = try? Data(contentsOf: machineIdentifierURL) else {
                fatalError("Failed to retrieve machine identifier data.")
            }
            guard let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
                fatalError("Failed to create machine identifier.")
            }
            macPlatformConfiguration.machineIdentifier = machineIdentifier
        }
        
        return macPlatformConfiguration
    }
    
#endif
    
}
