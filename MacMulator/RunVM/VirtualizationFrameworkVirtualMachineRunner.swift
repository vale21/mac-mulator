//
//  VirtualizationFrameworkVirtualMachineRunner.swift
//  MacMulator
//
//  Created by Vale on 14/04/22.
//

import Foundation
import Virtualization

@available(macOS 12.0, *)
class VirtualizationFrameworkVirtualMachineRunner : NSObject, VirtualMachineRunner, VZVirtualMachineDelegate {
    
    let managedVm: VirtualMachine;
    var vzVirtualMachine: VZVirtualMachine?;
    var running: Bool = false;
    var vmView: VZVirtualMachineView?;
    var vmViewController: VirtualMachineContainerViewController?;
    var recoveryMode: Bool = false
    
    init(virtualMachine: VirtualMachine) {
        managedVm = virtualMachine;
    }
    
    func getManagedVM() -> VirtualMachine {
        return managedVm;
    }
    
    func setVmView(_ vmView: VZVirtualMachineView) {
        self.vmView = vmView;
    }
    
    func setVmViewController(_ vmViewController: VirtualMachineContainerViewController) {
        self.vmViewController = vmViewController;
    }
        
    func runVM(uponCompletion callback: @escaping (VMExecutionResult, VirtualMachine) -> Void) {
        running = true;

        #if arch(arm64)
        
        vzVirtualMachine = createVirtualMachine(vm: managedVm);
        
        let isDriveBlank = Utils.findMainDrive(managedVm.drives)!.isBlank()
        if isDriveBlank {
            installAndStartVM()
        } else {
            startVM()
        }
    
        
        #endif
    }
    
    func instllationComplete(_ result: Result<Void, Error>) {
        if case let .failure(error) = result {
            Utils.showAlert(window: self.vmView!.window!, style: NSAlert.Style.critical, message: "Installation failed with error: " + error.localizedDescription )
        } else {
            Utils.findMainDrive(self.managedVm.drives)!.setBlank(blank: false)
            managedVm.writeToPlist()
            startVM();
        }
    }
    
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        print("Stopped")
        stopVM()
    }
    
    func isVMRunning() -> Bool {
        return running;
    }
    
    func startVM() {
        if let vzVirtualMachine = self.vzVirtualMachine {
            vzVirtualMachine.delegate = self;
            self.vmView?.virtualMachine = vzVirtualMachine;
            
            #if arch(arm64)
            if #available(macOS 13, *) {
                let options = VZMacOSVirtualMachineStartOptions()
                options.startUpFromMacOSRecovery = configuration.bootIntoMacOSRecovery
                //populateFromConfiguration(unsafeBitCast(options, to: _VZVirtualMachineStartOptions.self))
                //try await virtualMachine.start(options: options)
            } else {
                let options = unsafeBitCast(NSClassFromString("_VZVirtualMachineStartOptions")!, to: _VZVirtualMachineStartOptions.Type.self).init()
                //populateFromConfiguration(options)
                options.bootMacOSRecovery = configuration.bootIntoMacOSRecovery
                //try await unsafeBitCast(virtualMachine, to: _VZVirtualMachine.self)._start(with: options)
            }
            #endif
            

            vzVirtualMachine.start(completionHandler: { (result) in
                switch result {
                    case let .failure(error):
                    Utils.showAlert(window: (self.vmView?.window)!, style: NSAlert.Style.critical, message: "Virtual machine failed to start \(error)", completionHandler: {resp in self.stopVM()});
                    break;
                    default:
                        print(result)
                }
            })
        }
    }
    
    func stopVM() {
        running = false;
        do {
            try vzVirtualMachine?.requestStop()
        } catch {
            vzVirtualMachine?.stop(completionHandler: { err in })
        }
        vmViewController?.stopVM();
    }
    
    func pauseVM() {
    }
    
    func getConsoleOutput() -> String {
        return "";
    }
    
    func stopInstallation() {
        
    }
    
#if arch(arm64)
    
    fileprivate func createVirtualMachine(vm: VirtualMachine) -> VZVirtualMachine {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()

        virtualMachineConfiguration.platform = createMacPlatformConfiguration(vm: vm);
        virtualMachineConfiguration.cpuCount = vm.cpus;
        virtualMachineConfiguration.memorySize = UInt64(vm.memory) * (1024 * 1024);
        virtualMachineConfiguration.bootLoader = MacOSVirtualMachineConfigurationHelper.createBootLoader()
        
        let resolution = Utils.getResolutionElements(vm.displayResolution);
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
        
        let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: auxiliaryStorageURL)
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
    
    fileprivate func installAndStartVM() {
        self.vmViewController?.performSegue(withIdentifier: MacMulatorConstants.SHOW_INSTALLING_OS_SEGUE, sender: self)
    }
    
#endif
    
}
