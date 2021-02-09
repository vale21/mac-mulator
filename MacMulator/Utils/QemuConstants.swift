//
//  QemuConstants.swift
//  MacMulator
//
//  Created by Vale on 05/02/21.
//

import Foundation

class QemuConstants {

    static let VM_EXTENSION = "qvm";
    static let INFO_PLIST = "Info.plist";
    
    // Disk image constants
    
    enum ImgCommands: String {
        case Create = "create";
    }
    
    enum ImgTypes: String {
        case Qcow2 = "qcow2";
        case Raw = "raw";
    }
    
    enum MediaTypes: String {
        case Disk = "disk";
        case CdRom = "cdrom";
    }
    
    // Virtual Machine constants
    
    enum MachineTypes: String {
        case Mac99_pmu = "mac99,via=pmu";
    }
    
    enum BiosTypes: String {
        case Pc_bios = "pc-bios";
    }
    
    enum NetworkTypes: String {
        case Sungem = "sungem";
    }
    
    enum BootArgs: String {
        case CD = "d";
        case HD = "c";
    }
}
