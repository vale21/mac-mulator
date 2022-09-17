//
//  VMCreatorFactory.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation

class VMCreatorFactory {
    
    func create(vm: VirtualMachine) -> VMCreator {
        
        if #available(macOS 12.0, *) {
            if vm.type == MacMulatorConstants.APPLE_VM {
                return VirtualizationFrameworkVMCreator();
            }
        }
        
        return QemuVMCreator();
    }
    
    func getVMType(os: String, subtype: String, architecture: String) -> String {
        if Utils.isVirtualizationFrameworkPreferred(os: os, subtype: subtype, architecture: architecture) {
            return MacMulatorConstants.APPLE_VM
        }
        return MacMulatorConstants.QEMU_VM
    }
}
