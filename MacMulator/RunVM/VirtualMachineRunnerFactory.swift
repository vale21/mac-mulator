//
//  VirtualMachineRunnerFactory.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation

class VirtualMachineRunnerFactory {
    
    func create(listenPort: Int32, vm: VirtualMachine) -> VirtualmachineRunner {
        return QemuRunner(listenPort: listenPort, virtualMachine: vm);
    }
}
