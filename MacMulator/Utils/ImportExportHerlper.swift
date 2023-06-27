//
//  ImportExportHerlper.swift
//  MacMulator
//
//  Created by Vale on 27/11/22.
//

import Foundation

class ImportExportHerlper {
    
    static let PARALLELS_EXTENSION = "macvm"
    static let PARALLELS_TEMPLATE = "parallels_template"
    static let PARALLELS_AUXILIARY_STORAGE_NAME = "aux.bin"
    static let PARALLELS_DISK_NAME = "disk0.img"
    static let PARALLELS_HARDWARE_MODEL_NAME = "machw.bin"
    static let PARALLELS_MACHINE_IDENTIFIER_NAME = "macid.bin"
    
    static func exportVmToParallels(vm: VirtualMachine, destinationPath: String) throws {
        let parallelsVMPath = destinationPath + "/" + vm.displayName + "." + PARALLELS_EXTENSION
        try FileManager.default.copyItem(atPath: Bundle.main.path(forResource: PARALLELS_TEMPLATE, ofType: nil)!, toPath: parallelsVMPath)
        try FileManager.default.copyItem(atPath: vm.path + "/" + VirtualizationFrameworkSupport.AUXILIARY_STORAGE_NAME + "-0", toPath: parallelsVMPath + "/" + PARALLELS_AUXILIARY_STORAGE_NAME)
        try FileManager.default.copyItem(atPath: vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION, toPath: parallelsVMPath + "/" + PARALLELS_DISK_NAME)
        try FileManager.default.copyItem(atPath: vm.path + "/" + VirtualizationFrameworkSupport.HARDWARE_MODEL_NAME + "-0", toPath: parallelsVMPath + "/" + PARALLELS_HARDWARE_MODEL_NAME)
        try FileManager.default.copyItem(atPath: vm.path + "/" + VirtualizationFrameworkSupport.MACHINE_IDENTIFIER_NAME + "-0", toPath: parallelsVMPath + "/" + PARALLELS_MACHINE_IDENTIFIER_NAME)
    }
    
    static func importVmFromParallels(sourcePath: String) throws -> VirtualMachine {
        let vmName = NSURL(fileURLWithPath: sourcePath)
            .lastPathComponent!
            .replacingOccurrences(of: "." + ImportExportHerlper.PARALLELS_EXTENSION, with: "")
        
        let os = QemuConstants.OS_MAC
        let subtype = QemuConstants.SUB_MAC_VENTURA
        let architecture = QemuConstants.ARCH_ARM64
        let path = Utils.computeVMPath(vmName: vmName)
        let displayName = vmName
        let description = "Automatically imported from Parallels VM"
        let memory = Utils.getDefaultMemoryForSubType(os, subtype)
        let cpus = Utils.getCpusForSubType(os, subtype)
        let displayResolution = QemuConstants.RES_1280_768
        let displayOrigin = QemuConstants.ORIGIN
        let networkDevice = Utils.getNetworkForSubType(os, subtype)
        let hvf = Utils.getAccelForSubType(os, subtype)
        let vmType = VMCreatorFactory().getVMType(os: os, subtype: subtype, architecture: architecture)
        
        let vm = VirtualMachine(os: os, subtype: subtype, architecture: architecture, path: path, displayName: displayName, description: description, memory: Int32(memory), cpus: cpus, displayResolution: displayResolution, displayOrigin: displayOrigin, networkDevice: networkDevice, qemuBootloader: false, hvf: hvf, type: vmType);
        
        try! Utils.createDocumentPackage(vm.path)
        
        try FileManager.default.copyItem(atPath: sourcePath + "/" + PARALLELS_AUXILIARY_STORAGE_NAME, toPath: vm.path + "/" + VirtualizationFrameworkSupport.AUXILIARY_STORAGE_NAME + "-0")
        try FileManager.default.copyItem(atPath: sourcePath + "/" + PARALLELS_DISK_NAME, toPath: vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION)
        try FileManager.default.copyItem(atPath: sourcePath + "/" + PARALLELS_HARDWARE_MODEL_NAME, toPath: vm.path + "/" + VirtualizationFrameworkSupport.HARDWARE_MODEL_NAME + "-0")
        try FileManager.default.copyItem(atPath: sourcePath + "/" + PARALLELS_MACHINE_IDENTIFIER_NAME, toPath: vm.path + "/" + VirtualizationFrameworkSupport.MACHINE_IDENTIFIER_NAME + "-0")
        
        // Disk drive configured asynchronously
        Utils.computeSizeOfPhysicalDrive(vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION, uponCompletion: { infoCode, size in
            let virtualHDD = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_DISK + "-0." + MacMulatorConstants.DISK_EXTENSION,
                name: QemuConstants.MEDIATYPE_DISK + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_DISK,
                size: size)
            virtualHDD.setBlank(blank: false)
            vm.addVirtualDrive(virtualHDD)
            vm.writeToPlist()
            
        })
        
        vm.writeToPlist()
        return vm
    }
}
