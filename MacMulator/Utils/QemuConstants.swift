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
    
    static let MEDIATYPE_DISK = "disk";
    static let MEDIATYPE_CDROM = "cdrom";
    
    enum ImgCommands: String {
        case Create = "create";
    }
    
    enum ImgTypes: String {
        case Qcow2 = "qcow2";
        case Raw = "raw";
    }
    
    // Virtual Machine constants
    
    static let CD = "CD/DVD";
    static let HD = "Hard Disk";
    static let NET = "Network";
    
    static let ARG_CD = "d";
    static let ARG_HD = "c";
    static let ARG_NET = "n";
    
    static let OS_MAC = "macOS";
    static let OS_WIN = "Windows";
    static let OS_LINUX = "Linux";

    enum MachineTypes: String {
        case Mac99_pmu = "mac99,via=pmu";
    }
    
    enum BiosTypes: String {
        case Pc_bios = "pc-bios";
    }
    
    enum NetworkTypes: String {
        case Sungem = "sungem";
    }
}
