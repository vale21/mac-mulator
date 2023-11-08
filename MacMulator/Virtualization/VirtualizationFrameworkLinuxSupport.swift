//
//  VirtualizationFrameworkConstants.swift
//  MacMulator
//
//  Created by Vale on 17/09/22.
//

import Foundation
import Virtualization

@available(macOS 12.0, *)
class VirtualizationFrameworkLinuxSupport : VirtualizationFrameworkSupport{
      
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
        if #available(macOS 14.0, *) {
#if arch(arm64)
            do {
                try virtualMachineConfiguration.validateSaveRestoreSupport()
                vm.pauseSupported = true
            } catch {
                NSLog("VM Pause is not supported: " + error.localizedDescription)
                vm.pauseSupported = false
            }
#else
        vm.pauseSupported = false
#endif
        }
        
        return virtualMachineConfiguration
    }
    
    @available(macOS 13.0, *)
    fileprivate static func createLinuxPlatformConfiguration(vm: VirtualMachine, isInstalling: Bool)  -> VZGenericPlatformConfiguration {
        let linuxPlatformConfiguration = VZGenericPlatformConfiguration()
        
        let machineIdentifierURL = URL(fileURLWithPath: vm.path + "/" + VirtualizationFrameworkLinuxSupport.MACHINE_IDENTIFIER_NAME + "-0")
        
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
        
        let efiVariableStorePath = vm.path + "/" + VirtualizationFrameworkLinuxSupport.EFI_VARIABLE_STORE_NAME + "-0"
        
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
