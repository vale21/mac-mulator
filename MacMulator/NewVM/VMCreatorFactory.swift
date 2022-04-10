//
//  VMCreatorFactory.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation

class VMCreatorFactory {
    
    func create(vm: VirtualMachine) -> VMCreator {
        return QemuVMCreator();
    }
}
