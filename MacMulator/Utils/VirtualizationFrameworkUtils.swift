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
    static let EFI_VARIABLE_STORE_NAME = "efi-var-store"
    
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
        virtualMachineConfiguration.networkDevices = [MacOSVirtualMachineConfigurationHelper.createNetworkDeviceConfiguration()]
        virtualMachineConfiguration.pointingDevices = [MacOSVirtualMachineConfigurationHelper.createPointingDeviceConfiguration()]
        virtualMachineConfiguration.keyboards = [MacOSVirtualMachineConfigurationHelper.createKeyboardConfiguration()]
        virtualMachineConfiguration.audioDevices = [MacOSVirtualMachineConfigurationHelper.createAudioDeviceConfiguration()]
        
        try! virtualMachineConfiguration.validate()
        
        return virtualMachineConfiguration
    }
    
    fileprivate static func createMacPlatformConfiguration(vm: VirtualMachine, macOSConfiguration: VZMacOSConfigurationRequirements?) -> VZMacPlatformConfiguration {
        let macPlatformConfiguration = VZMacPlatformConfiguration()
        let auxiliaryStorageURL = URL(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkUtils.AUXILIARY_STORAGE_NAME + "-0")
        let machineIdentifierURL = URL(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkUtils.MACHINE_IDENTIFIER_NAME + "-0")
        let hardwareModelURL = URL(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkUtils.HARDWARE_MODEL_NAME + "-0")
        
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
    
    @available(macOS 13.0, *)
    static func createLinuxVirtualMachineData(vm: VirtualMachine) {
        
        _ = createLinuxPlatformConfiguration(vm: vm, isInstalling: true)
        _ = createLinuxBootloader(vm: vm, isInstalling: true)
    }
    
    @available(macOS 13.0, *)
    static func decodeLinuxVirtualMachine(vm: VirtualMachine, installMedia: String) -> VZVirtualMachine {
        let configuration = setupLinuxVirtualMachine(vm: vm, installMedia: installMedia)
        
        let virtualMachine = VZVirtualMachine(configuration: configuration, queue: .main)
        return virtualMachine;
    }
    
    @available(macOS 13.0, *)
    fileprivate static func setupLinuxVirtualMachine(vm: VirtualMachine, installMedia: String) -> VZVirtualMachineConfiguration {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()
        virtualMachineConfiguration.platform = createLinuxPlatformConfiguration(vm: vm, isInstalling: false)
        virtualMachineConfiguration.cpuCount = vm.cpus
        virtualMachineConfiguration.memorySize = UInt64(vm.memory) * (1024 * 1024)
        virtualMachineConfiguration.bootLoader = createLinuxBootloader(vm: vm, isInstalling: false)
        
        let resolution = Utils.getResolutionElements(vm.displayResolution)
        
        virtualMachineConfiguration.graphicsDevices = [LinuxVirtualMachineConfigurationHelper.createGraphicsDeviceConfiguration(
            witdh: resolution[0],
            height: resolution[1])]
        
        let disksArray = NSMutableArray()
        if installMedia != "" {
            disksArray.add(LinuxVirtualMachineConfigurationHelper.createUSBMassStorageDeviceConfiguration(installMedia))
        }
        disksArray.add(LinuxVirtualMachineConfigurationHelper.createBlockDeviceConfiguration(path: Utils.findMainDrive(vm.drives)!.path))
        guard let disks = disksArray as? [VZStorageDeviceConfiguration] else {
            fatalError("Invalid disksArray.")
        }
        
        virtualMachineConfiguration.storageDevices = disks
        virtualMachineConfiguration.networkDevices = [LinuxVirtualMachineConfigurationHelper.createNetworkDeviceConfiguration()]
        virtualMachineConfiguration.pointingDevices = [LinuxVirtualMachineConfigurationHelper.createPointingDeviceConfiguration()]
        virtualMachineConfiguration.keyboards = [LinuxVirtualMachineConfigurationHelper.createKeyboardConfiguration()]
        virtualMachineConfiguration.audioDevices = [LinuxVirtualMachineConfigurationHelper.createAudioDeviceConfiguration()]
        virtualMachineConfiguration.consoleDevices = [LinuxVirtualMachineConfigurationHelper.createSpiceAgentConsoleDeviceConfiguration()]
        
        try! virtualMachineConfiguration.validate()
        
        return virtualMachineConfiguration
    }
    
    @available(macOS 13.0, *)
    fileprivate static func createLinuxPlatformConfiguration(vm: VirtualMachine, isInstalling: Bool)  -> VZGenericPlatformConfiguration {
        let linuxPlatformConfiguration = VZGenericPlatformConfiguration()
        
        let machineIdentifierURL = URL(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkUtils.MACHINE_IDENTIFIER_NAME + "-0")
        
        if isInstalling {
            linuxPlatformConfiguration.machineIdentifier = VZGenericMachineIdentifier()
            try! linuxPlatformConfiguration.machineIdentifier.dataRepresentation.write(to: machineIdentifierURL)
        } else {
            guard let machineIdentifierData = try? Data(contentsOf: machineIdentifierURL) else {
                fatalError("Failed to retrieve machine identifier data.")
            }
            guard let machineIdentifier = VZGenericMachineIdentifier(dataRepresentation: machineIdentifierData) else {
                fatalError("Failed to create machine identifier.")
            }
            linuxPlatformConfiguration.machineIdentifier = machineIdentifier
        }
        
        return linuxPlatformConfiguration
    }
    
    @available(macOS 13.0, *)
    fileprivate static func createLinuxBootloader(vm: VirtualMachine, isInstalling: Bool)  -> VZEFIBootLoader {
        let bootloader = VZEFIBootLoader()
        
        let efiVariableStorePath = vm.path + "/" + VirtualizationFrameworkUtils.EFI_VARIABLE_STORE_NAME + "-0"
        
        if isInstalling {
            bootloader.variableStore = LinuxVirtualMachineConfigurationHelper.createEFIVariableStore(path: efiVariableStorePath)
        } else {
            if !FileManager.default.fileExists(atPath: efiVariableStorePath) {
                fatalError("EFI variable store does not exist.")
            }
            
            bootloader.variableStore = VZEFIVariableStore(url: URL(fileURLWithPath: efiVariableStorePath))
        }
        
        return bootloader
    }
}
