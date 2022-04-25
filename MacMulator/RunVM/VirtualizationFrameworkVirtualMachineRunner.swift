//
//  VirtualizationFrameworkVirtualMachineRunner.swift
//  MacMulator
//
//  Created by Vale on 14/04/22.
//

import Foundation
import Virtualization

@available(macOS 11.0, *)
protocol VirtualMachineObserver {
    
    func virtualMachineStarted(_ vm: VZVirtualMachine);
    
    func virtualmachinePaused(_ vm: VZVirtualMachine);
    
    func virtualMachineStopped(_ vm: VZVirtualMachine);
}

@available(macOS 11.0, *)
extension VirtualMachineObserver {
    
    func virtualMachineStarted(_ vm: VZVirtualMachine) {};
    
    func virtualmachinePaused(_ vm: VZVirtualMachine) {};
    
    func virtualMachineStopped(_ vm: VZVirtualMachine) {};
}

@available(macOS 12.0, *)
class VirtualizationFrameworkVirtualMachineRunner : NSObject, VirtualMachineRunner, VZVirtualMachineDelegate {
    
    let managedVm: VirtualMachine;
    var vzVirtualMachine: VZVirtualMachine?;
    var running: Bool = false;
    var callback: (VMExecutionResult, VirtualMachine) -> Void = { result, vm in };
    var vmView: VZVirtualMachineView?;
    var observers: [VirtualMachineObserver] = [];
    
    init(virtualMachine: VirtualMachine) {
        managedVm = virtualMachine;
    }
    
    func getManagedVM() -> VirtualMachine {
        return managedVm;
    }
    
    func setVmView(_ vmView: VZVirtualMachineView) {
        self.vmView = vmView;
    }
    
    func runVM(uponCompletion callback: @escaping (VMExecutionResult, VirtualMachine) -> Void) {
        running = true;
        self.callback = callback;
        
        #if arch(arm64)
        
        vzVirtualMachine = createVirtualMachine(vm: managedVm);
        
        if let vzVirtualMachine = self.vzVirtualMachine {
            vzVirtualMachine.delegate = self;
            
            vmView?.virtualMachine = vzVirtualMachine;
            
            vzVirtualMachine.start(completionHandler: { (result) in
                switch result {
                    case let .failure(error):
                        fatalError("Virtual machine failed to start \(error)")

                    default:
                        self.stopVM();
                }
            })
        }
        
        #endif
    }
    
    func isVMRunning() -> Bool {
        return running;
    }
    
    func stopVM() {
        running = false;
        callback(VMExecutionResult(exitCode: 0), managedVm);
        
        observers.forEach { observer in
            observer.virtualMachineStopped(vzVirtualMachine!);
        }
    }
    
    func pauseVM() {
        observers.forEach { observer in
            observer.virtualmachinePaused(vzVirtualMachine!);
        }
    }
    
    func getConsoleOutput() -> String {
        return "";
    }
    
    func addObserver(_ observer: VirtualMachineObserver) {
        observers.append(observer);
        if (running) {
            observer.virtualMachineStarted(vzVirtualMachine!);
        }
    }
    
#if arch(arm64)
    
    fileprivate func createVirtualMachine(vm: VirtualMachine) -> VZVirtualMachine {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()
        
        virtualMachineConfiguration.platform = createMacPlatformConfiguration(vm: vm);
        virtualMachineConfiguration.cpuCount = vm.cpus;
        virtualMachineConfiguration.memorySize = UInt64(vm.memory) * (1024 * 1024);
        virtualMachineConfiguration.bootLoader = MacOSVirtualMachineConfigurationHelper.createBootLoader()
        
        let resolution = Utils.getResolutionElements(vm.displayResolution);
        virtualMachineConfiguration.graphicsDevices = [MacOSVirtualMachineConfigurationHelper.createGraphicsDeviceConfiguration(witdh: resolution[0], height: resolution[1], ppi: 220)]
        virtualMachineConfiguration.storageDevices = [MacOSVirtualMachineConfigurationHelper.createBlockDeviceConfiguration(path: vm.drives[0].path)]
        virtualMachineConfiguration.networkDevices = [MacOSVirtualMachineConfigurationHelper.createNetworkDeviceConfiguration()]
        virtualMachineConfiguration.pointingDevices = [MacOSVirtualMachineConfigurationHelper.createPointingDeviceConfiguration()]
        virtualMachineConfiguration.keyboards = [MacOSVirtualMachineConfigurationHelper.createKeyboardConfiguration()]
        virtualMachineConfiguration.audioDevices = [MacOSVirtualMachineConfigurationHelper.createAudioDeviceConfiguration()]
        virtualMachineConfiguration.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        
        
        
        try! virtualMachineConfiguration.validate()
        
        let virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration, queue: .main)
        return virtualMachine;
    }
    
    fileprivate func createMacPlatformConfiguration(vm: VirtualMachine) -> VZMacPlatformConfiguration {
        let macPlatformConfiguration = VZMacPlatformConfiguration()
        let auxiliaryStorageURL = URL(fileURLWithPath: vm.path + "/AuxiliaryStorage")
        let machineIdentifierURL = URL(fileURLWithPath: vm.path + "/MachineIdentifier")
        let hardwareModelURL = URL(fileURLWithPath: vm.path + "/HardwareModel")
        
        guard let hardwareModelData = try? Data(contentsOf: hardwareModelURL) else {
            fatalError("Failed to retrieve hardware model data.")
        }

        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData) else {
            fatalError("Failed to create hardware model.")
        }
        
        macPlatformConfiguration.hardwareModel = hardwareModel;
        
        let auxiliaryStorage = try? VZMacAuxiliaryStorage(
                    creatingStorageAt: auxiliaryStorageURL,
                    hardwareModel: hardwareModel,
                    options: [.allowOverwrite]
                )
        macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage
    

        guard let machineIdentifierData = try? Data(contentsOf: machineIdentifierURL) else {
            fatalError("Failed to retrieve machine identifier data.")
        }

        guard let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            fatalError("Failed to create machine identifier.")
        }
        macPlatformConfiguration.machineIdentifier = machineIdentifier
        
        return macPlatformConfiguration
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        NSLog("Virtual machine did stop with error: \(error.localizedDescription)")
        exit(-1)
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        NSLog("Guest did stop virtual machine.")
        exit(0)
    }

#endif
    
}
