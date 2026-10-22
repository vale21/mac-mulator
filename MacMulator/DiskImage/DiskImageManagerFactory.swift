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
}
