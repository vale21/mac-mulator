//
//  ImportExportHerlper.swift
//  MacMulator
//
//  Created by Vale on 27/11/22.
//

import Foundation

class ImportExportHerlper {
    
    static let PARALLELS_TEMPLATE = "parallels_template"
    static let PARALLELS_AUXILIARY_STORAGE_NAME = "aux.bin"
    static let PARALLELS_DISK_NAME = "disk0.img"
    static let PARALLELS_HARDWARE_MODEL_NAME = "machw.bin"
    static let PARALLELS_MACHINE_IDENTIFIER_NAME = "macid.bin"
    
    static func exportVmToParallels(vm: VirtualMachine, destinationPath: String) {
        do {
            let parallelsVMPath = destinationPath + "/" + vm.displayName + ".macvm"
            try FileManager.default.copyItem(atPath: Bundle.main.path(forResource: PARALLELS_TEMPLATE, ofType: nil)!, toPath: parallelsVMPath)
            try FileManager.default.copyItem(atPath: vm.path + "/" + VirtualizationFrameworkSupport.AUXILIARY_STORAGE_NAME + "-0", toPath: parallelsVMPath + "/" + PARALLELS_AUXILIARY_STORAGE_NAME)
            try FileManager.default.copyItem(atPath: vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION, toPath: parallelsVMPath + "/" + PARALLELS_DISK_NAME)
            try FileManager.default.copyItem(atPath: vm.path + "/" + VirtualizationFrameworkSupport.HARDWARE_MODEL_NAME + "-0", toPath: parallelsVMPath + "/" + PARALLELS_HARDWARE_MODEL_NAME)
            try FileManager.default.copyItem(atPath: vm.path + "/" + VirtualizationFrameworkSupport.MACHINE_IDENTIFIER_NAME + "-0", toPath: parallelsVMPath + "/" + PARALLELS_MACHINE_IDENTIFIER_NAME)
        } catch {
           
        }
    }
}
