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
    
    let managedVm: VirtualMachine
    let saveFileURL: URL
    var vzVirtualMachine: VZVirtualMachine?
    var vmView: VZVirtualMachineView?
    var vmViewController: VirtualMachineContainerViewController?
    var recoveryMode: Bool = false
    
    init(virtualMachine: VirtualMachine) {
        managedVm = virtualMachine;
        saveFileURL = URL(fileURLWithPath: self.managedVm.path).appendingPathComponent(MacMulatorConstants.SAVE_FILE_NAME)
    }
    
    func getManagedVM() -> VirtualMachine {
        return managedVm;
    }
    
    func setVmView(_ vmView: VZVirtualMachineView) {
        self.vmView = vmView
    }
    
    func setVmViewController(_ vmViewController: VirtualMachineContainerViewController) {
        self.vmViewController = vmViewController;
    }
    
    func runVM(recoveryMode: Bool, uponCompletion callback: @escaping (VMExecutionResult, VirtualMachine) -> Void) {
        self.recoveryMode = recoveryMode
        
        if Utils.isMacVMWithOSVirtualizationFramework(os: managedVm.os, subtype: managedVm.subtype) {
#if arch(arm64)
            
            vzVirtualMachine = VirtualizationFrameworkMacOSSupport.decodeMacOSVirtualMachine(vm: managedVm)

            let isDriveBlank = Utils.findMainDrive(managedVm.drives)!.isBlank()
            if isDriveBlank {
                installAndStartVM()
            } else {
                startOrResumeVM()
            }
            
#endif
        } else if #available(macOS 13.0, *) {
            let installMedia = Utils.findUSBInstallDrive(managedVm.drives)
            var installPath: String? = nil
            if let installMedia = installMedia {
                installPath = installMedia.path
            } else {
                installPath = ""
            }
            vzVirtualMachine = VirtualizationFrameworkLinuxSupport.decodeLinuxVirtualMachine(vm: managedVm, installMedia: installPath!)
            startOrResumeVM()
        }
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
        stopVM(guestStopped: true)
    }
    
    func isVMRunning() -> Bool {
        return vzVirtualMachine != nil && vzVirtualMachine!.state == VZVirtualMachine.State.running
    }
    
    func startVM() {
        if let vzVirtualMachine = self.vzVirtualMachine {
            vzVirtualMachine.delegate = self
            self.vmView?.virtualMachine = vzVirtualMachine
            if #available(macOS 14.0, *) {
                self.vmView?.automaticallyReconfiguresDisplay = true
            }
            self.vmView?.capturesSystemKeys = true
            
            if #available(macOS 13.0, *), Utils.isMacVMWithOSVirtualizationFramework(os: managedVm.os, subtype: managedVm.subtype) {
                
#if arch(arm64)
                
                let options = VZMacOSVirtualMachineStartOptions()
                options.startUpFromMacOSRecovery = self.recoveryMode
                
                vzVirtualMachine.start(options: options, completionHandler: { error in
                    if let error = error {
                        Utils.showAlert(window: (self.vmView?.window)!, style: NSAlert.Style.critical, message: "Virtual machine failed to start \(error)", completionHandler: {resp in self.stopVM(guestStopped: true)});
                    }
                })
                
#endif
                
            } else {
                vzVirtualMachine.start(completionHandler: { (result) in
                    switch result {
                    case let .failure(error):
                        Utils.showAlert(window: (self.vmView?.window)!, style: NSAlert.Style.critical, message: "Virtual machine failed to start \(error)", completionHandler: {resp in self.stopVM(guestStopped: true)});
                        break;
                    default:
                        print(result)
                    }
                })
            }
        }
    }
    
    @available(macOS 14.0, *)
    func resumeVM() {
        if let vzVirtualMachine = self.vzVirtualMachine {
            vzVirtualMachine.delegate = self
            self.vmView?.virtualMachine = vzVirtualMachine
            self.vmView?.automaticallyReconfiguresDisplay = true
            self.vmView?.capturesSystemKeys = true
            
            vzVirtualMachine.resume(completionHandler: { (result) in
                if case let .failure(error) = result {
                    Utils.showAlert(window: (self.vmView?.window)!, style: NSAlert.Style.critical, message: "Virtual machine failed to resume \(error)", completionHandler: {resp in self.stopVM(guestStopped: true)});
                }
                NSLog(String(vzVirtualMachine.state.rawValue))
            })
        }
    }
    
    func stopVM(guestStopped: Bool) {
        vzVirtualMachine?.stop(completionHandler: { err in })
        vmViewController?.stopVM(guestStopped)
    }
    
    func stopVMGracefully() {
        do {
            try vzVirtualMachine?.requestStop()
        } catch {
            self.stopVM(guestStopped: false)
        }
        vmViewController?.stopVM(false);
    }
    
    func pauseVM() {
        if #available(macOS 14.0, *) {
            if let vzVirtualMachine = self.vzVirtualMachine {
                if vzVirtualMachine.state == .running {
                    vmViewController?.takeScreenshot()
                    vmViewController?.showPausingView()
#if arch(arm64)
                    pauseAndSaveVirtualMachine(completionHandler: {
                        self.stopVM(guestStopped: true)
                    })
#endif
                }
            }
        }
    }
    
    func abort() {
        vmViewController?.view.window?.close()
    }
    
    func getConsoleOutput() -> String {
        return "";
    }
    
    fileprivate func startOrResumeVM() {
        if #available(macOS 14.0, *) {
#if arch(arm64)
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: saveFileURL.path) {
                restoreVirtualMachine()
            } else {
                startVM()
            }
#else
            startVM()
#endif
        } else {
            startVM()
        }
    }
    
    fileprivate func installAndStartVM() {
        self.vmViewController?.performSegue(withIdentifier: MacMulatorConstants.SHOW_INSTALLING_OS_SEGUE, sender: self)
    }
    
#if arch(arm64)
    
    @available(macOS 14.0, *)
    fileprivate func restoreVirtualMachine() {
        vmViewController?.showResumingView()
        vzVirtualMachine?.restoreMachineStateFrom(url: saveFileURL, completionHandler: { error in
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: self.saveFileURL)
            try? fileManager.removeItem(at: URL(fileURLWithPath: self.managedVm.path + "/" + MacMulatorConstants.SCREENSHOT_FILE_NAME))
            
            if error == nil {
                self.resumeVM()
            } else {
                self.startVM()
            }
        })
    }
        
    @available(macOS 14.0, *)
    func saveVirtualMachine(completionHandler: @escaping () -> Void) {
        vzVirtualMachine?.saveMachineStateTo(url: saveFileURL, completionHandler: { (error) in
            guard error == nil else {
                fatalError("Virtual machine failed to save with \(error!)")
            }

            completionHandler()
        })
    }

    @available(macOS 14.0, *)
    func pauseAndSaveVirtualMachine(completionHandler: @escaping () -> Void) {
        vzVirtualMachine?.pause(completionHandler: { (result) in
            if case let .failure(error) = result {
                fatalError("Virtual machine failed to pause with \(error)")
            }

            self.saveVirtualMachine(completionHandler: completionHandler)
        })
    }
    
#endif
}
