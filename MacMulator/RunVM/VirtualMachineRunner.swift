//
//  VirtualMachineRunner.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation

class VMExecutionResult {
    
    let exitCode: Int32;
    let error: String?
    
    init(exitCode: Int32) {
        self.exitCode = exitCode;
        error = nil;
    }
    
    init(exitCode: Int32, error: String) {
        self.exitCode = exitCode;
        self.error = error;
    }
}

protocol VirtualMachineRunner {
    
    func getManagedVM() -> VirtualMachine;
            
    func runVM(recoveryMode: Bool, uponCompletion callback: @escaping (VMExecutionResult, VirtualMachine) -> Void);
    
    func isVMRunning() -> Bool;
    
    func stopVM();
    
    func pauseVM();
    
    func getConsoleOutput() -> String
}
