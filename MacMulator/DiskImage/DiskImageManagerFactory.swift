//
//  DiskImageManagerFactory.swift
//  MacMulator
//
//  Created by Vale on 22/10/2026.
//

import Foundation

class DiskImageManagerFactory {
    func create(isVirtualizationFrameworkInUse: Bool) -> DiskImageManager {
        if isVirtualizationFrameworkInUse {
            return VirtualizationFrameworkDiskImageManager()
        }
        return QemuDiskImageManager()
    }

    func create(forVM: VirtualMachine) -> DiskImageManager {
        if forVM.type == MacMulatorConstants.APPLE_VM {
            return VirtualizationFrameworkDiskImageManager()
        }
        return QemuDiskImageManager()
    }
}
