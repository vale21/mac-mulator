//
//  VMCreatorFactory.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation

class VMCreatorFactory {
    
    func create(vm: VirtualMachine) -> VMCreator {
        
        if vm.type == MacMulatorConstants.APPLE_VM {
            if #available(macOS 12.0, *) {
                return VirtualizationFrameworkVMCreator();
            }
        }
        
        return QemuVMCreator();
    }
    
    func getVMType(os: String, subtype: String, architecture: String) -> String {
        #if arch(arm64)
        if Utils.isAppleSiliconOnlyVM(os: os, subtype: subtype, architecture: architecture) {
            if #available(macOS 12.0, *) {
                return MacMulatorConstants.APPLE_VM
            }
        }
        #endif

        return MacMulatorConstants.QEMU_VM
    }
}
