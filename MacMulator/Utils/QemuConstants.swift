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
    static let IMAGE_CMD_CREATE = "create";
    static let IMAGE_TYPE_QCOW2 = "qcow2";
    static let IMAGE_TYPE_RAW = "raw";
    
    // Virtual Machine constants
    
    static let CD = "CD/DVD";
    static let HD = "Hard Drive";
    static let NET = "Network";
    
    static let ARG_CD = "d";
    static let ARG_HD = "c";
    static let ARG_NET = "n";
    
    static let OS_MAC = "macOS";
    static let OS_WIN = "Windows";
    static let OS_LINUX = "Linux";
    
    static let ARCH_PPC = "qemu-system-ppc";
    static let ARCH_X86 = "qemu-system-i386";
    static let ARCH_X64 = "qemu-system-x86_64";
    static let ARCH_ARM = "qemu-system-arm";
    static let ARCH_ARM64 = "qemu-system-aarch64";
    static let ARCH_68K = "qemu-system-m68k";
    
    static let ALL_ARCHITECTURES = [
        ARCH_X64,
        ARCH_X86,
        ARCH_PPC,
        ARCH_ARM,
        ARCH_ARM64,
        ARCH_68K
    ]
    
    static let MAX_CPUS: [String:Int] = [
        ARCH_PPC: 1,
        ARCH_X86: 4,
        ARCH_X64: 16,
        ARCH_ARM: 2,
        ARCH_ARM64: 8,
        ARCH_68K: 1
    ]
    
    // 4:3
    static let RES_640_480 = "640x480x32";
    static let RES_800_600 = "800x600x32";
    static let RES_1024_768 = "1024x768x32";
    static let RES_1280_1024 = "1280x1024x32";
    static let RES_1600_1200 = "1600x1200x32";
    
    // 11:10
    static let RES_1024_600 = "1024x600x32";
    static let RES_1280_800 = "1280x800x32";
    static let RES_1440_900 = "1440x900x32";
    static let RES_1680_1050 = "1680x1050x32";
    static let RES_1920_1200 = "1920x1200x32";
    
    // 11:9
    static let RES_1280_720 = "1280x720x32";
    static let RES_1920_1080 = "1920x1080x32";
    static let RES_2048_1152 = "2048x1152x32";
    static let RES_2560_1440 = "2560x1440x32";
    static let RES_3840_2160 = "3840x2160x32";
    static let RES_4096_2160 = "4096x2160x32";
    static let RES_5120_2280 = "5120×2880x32";
    static let RES_6016_3384 = "6016×3384x32";
    
    static let ALL_RESOLUTIONS = [
        RES_640_480,
        RES_800_600,
        RES_1024_768,
        RES_1280_1024,
        RES_1600_1200,
        RES_1024_600,
        RES_1280_800,
        RES_1440_900,
        RES_1680_1050,
        RES_1920_1200,
        RES_1280_720,
        RES_1920_1080,
        RES_2048_1152,
        RES_2560_1440,
        RES_3840_2160,
        RES_4096_2160,
        RES_5120_2280,
        RES_6016_3384
    ]
    
    

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
