//
//  VirtualMachineRunnerFactory.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation

class VirtualMachineRunnerFactory {
    
    func create(listenPort: Int32, vm: VirtualMachine) -> VirtualMachineRunner {
        if (vm.os == QemuConstants.OS_MAC && vm.subtype == QemuConstants.SUB_MAC_MONTEREY) {
            return VirtualizationFrameworkVirtualMachineRunner(virtualMachine: vm);
        }
        return QemuRunner(listenPort: listenPort, virtualMachine: vm);
    }
}
