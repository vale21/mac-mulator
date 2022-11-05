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
        
    func runVM(recoveryMode: Bool, uponCompletion callback: @escaping (VMExecutionResult, VirtualMachine) -> Void) {
        self.recoveryMode = recoveryMode
        running = true;

        #if arch(arm64)
        
        vzVirtualMachine = VirtualizationFrameworkUtils.decodeVirtualMachine(vm: managedVm);
        
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
            
            if #available(macOS 13.0, *) {
                let options = VZMacOSVirtualMachineStartOptions()
                options.startUpFromMacOSRecovery = self.recoveryMode
                
                vzVirtualMachine.start(options: options, completionHandler: { error in
                    if let error = error {
                        Utils.showAlert(window: (self.vmView?.window)!, style: NSAlert.Style.critical, message: "Virtual machine failed to start \(error)", completionHandler: {resp in self.stopVM()});
                    }
                })
            } else {
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
    
    fileprivate func installAndStartVM() {
        self.vmViewController?.performSegue(withIdentifier: MacMulatorConstants.SHOW_INSTALLING_OS_SEGUE, sender: self)
    }
}
