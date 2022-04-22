//
//  VirtualMachineRunnerFactory.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation

class VirtualMachineRunnerFactory {
    
    func create(listenPort: Int32, vm: VirtualMachine) -> VirtualMachineRunner {
        
        #if arch(arm64)
        if (vm.os == QemuConstants.OS_MAC && vm.subtype == QemuConstants.SUB_MAC_MONTEREY) {
            if #available(macOS 12.0, *) {
                return VirtualizationFrameworkVirtualMachineRunner(virtualMachine: vm);
            }
        }
        #endif
        
        return QemuRunner(listenPort: listenPort, virtualMachine: vm);
    }
}
