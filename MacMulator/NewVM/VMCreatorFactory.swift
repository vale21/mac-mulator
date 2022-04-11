//
//  VMCreatorFactory.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation

class VMCreatorFactory {
    
    func create(vm: VirtualMachine) -> VMCreator {
        
        #if arch(arm64)
        if vm.os == QemuConstants.OS_MAC && vm.subtype == QemuConstants.SUB_MAC_MONTEREY {
            if #available(macOS 12.0, *) {
                return VirtualizationFrameworkVMCreator();
            }
        }
        #endif
        
        return QemuVMCreator();
    }
}
