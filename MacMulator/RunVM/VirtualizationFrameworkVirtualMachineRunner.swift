//
//  VirtualizationFrameworkVirtualMachineRunner.swift
//  MacMulator
//
//  Created by Vale on 14/04/22.
//

import Foundation

protocol VirtualMachineObserver {
    
    func virtualMachineStarted();
    
    func virtualmachinePaused();
    
    func virtualMachineStopped();
}

extension VirtualMachineObserver {
    
    func virtualMachineStarted() {};
    
    func virtualmachinePaused() {};
    
    func virtualMachineStopped() {};
}

class VirtualizationFrameworkVirtualMachineRunner : VirtualMachineRunner {
    
    let managedVm: VirtualMachine;
    var running: Bool = false;
    var callback: (VMExecutionResult, VirtualMachine) -> Void = { result, vm in };
    var observers: [VirtualMachineObserver] = [];
    
    init(virtualMachine: VirtualMachine) {
        managedVm = virtualMachine;
    }
    
    func getManagedVM() -> VirtualMachine {
        return managedVm;
    }
    
    func runVM(uponCompletion callback: @escaping (VMExecutionResult, VirtualMachine) -> Void) {
        running = true;
        self.callback = callback;
        
        observers.forEach { observer in
            observer.virtualMachineStarted();
        }
    }
    
    func isVMRunning() -> Bool {
        return running;
    }
    
    func stopVM() {
        running = false;
        callback(VMExecutionResult(exitCode: 0), managedVm);
        
        observers.forEach { observer in
            observer.virtualMachineStopped();
        }
    }
    
    func pauseVM() {
        observers.forEach { observer in
            observer.virtualmachinePaused();
        }
    }
    
    func getConsoleOutput() -> String {
        return "";
    }
    
    func addObserver(_ observer: VirtualMachineObserver) {
        observers.append(observer);
    }
}
