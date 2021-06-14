//
//  QemuConstants.swift
//  MacMulator
//
//  Created by Vale on 05/02/21.
//

import Foundation

class QemuConstants {

    // Disk image constants
    
    static let MEDIATYPE_DISK = "disk";
    static let MEDIATYPE_CDROM = "cdrom";
    
    static let IMAGE_CMD_CREATE = "create";
    static let IMAGE_CMD_INFO = "info";
    static let IMAGE_CMD_RESIZE = "resize";
    static let IMAGE_CMD_CONVERT = "convert";
    
    static let FORMAT_QCOW2 = "qcow2";
    static let FORMAT_RAW = "raw";
    
    // Virtual Machine constants
    
    static let CD = "CD/DVD";
    static let HD = "Hard Drive";
    static let NET = "Network";
    
    static let ARG_CD = "d";
    static let ARG_HD = "c";
    static let ARG_NET = "n";
    static let ARG_BOOTLOADER = "menu=on";
    
    static let OS_MAC = "macOS";
    static let OS_WIN = "Windows";
    static let OS_LINUX = "Linux";
    static let OS_OTHER = "Other";
    
    static let QEMU_IMG = "qemu-img";
    static let ARCH_PPC = "qemu-system-ppc";
    static let ARCH_PPC64 = "qemu-system-ppc64";
    static let ARCH_X86 = "qemu-system-i386";
    static let ARCH_X64 = "qemu-system-x86_64";
    static let ARCH_ARM = "qemu-system-arm";
    static let ARCH_ARM64 = "qemu-system-aarch64";
    static let ARCH_68K = "qemu-system-m68k";
    static let ARCH_RISCV32 = "qemu-system-riscv32"
    static let ARCH_RISCV64 = "qemu-system-riscv64"
    
    static let ALL_ARCHITECTURES = [
        ARCH_X64,
        ARCH_X86,
        ARCH_PPC,
        ARCH_PPC64,
        ARCH_ARM,
        ARCH_ARM64,
        ARCH_68K,
        ARCH_RISCV32,
        ARCH_RISCV64
    ]
    
    static let ALL_ARCHITECTURES_DESC: [String:String] = [
        QemuConstants.ARCH_X64: "Intel/AMD 64bit",
        QemuConstants.ARCH_X86: "Intel/AMD 32bit",
        QemuConstants.ARCH_PPC: "PowerPc 32bit",
        QemuConstants.ARCH_PPC64: "PowerPc 64bit",
        QemuConstants.ARCH_ARM: "ARM",
        QemuConstants.ARCH_ARM64: "ARM 64bit",
        QemuConstants.ARCH_68K: "Motorola 68k",
        QemuConstants.ARCH_RISCV32: "RISC-V 32bit",
        QemuConstants.ARCH_RISCV64: "RISC-V 64bit"
    ];
    
    static let MAX_CPUS: [String:Int] = [
        ARCH_PPC: 1,
        ARCH_PPC64: 1,
        ARCH_X86: 4,
        ARCH_X64: 16,
        ARCH_ARM: 2,
        ARCH_ARM64: 8,
        ARCH_68K: 1,
        ARCH_RISCV32: 2,
        ARCH_RISCV64: 8
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

    static let ALL_RESOLUTIONS_DESC: [String:String] = [
        QemuConstants.RES_640_480: "640 x 480",
        QemuConstants.RES_800_600: "800 x 600",
        QemuConstants.RES_1024_768: "1024 x 768",
        QemuConstants.RES_1280_1024: "1280 x 1024",
        QemuConstants.RES_1600_1200: "1600 x 1200",
        QemuConstants.RES_1024_600: "1024 x 600",
        QemuConstants.RES_1280_800: "1280 x 800",
        QemuConstants.RES_1440_900: "1440 x 900",
        QemuConstants.RES_1680_1050: "1680 x 1050",
        QemuConstants.RES_1920_1200: "1920 x 1200",
        QemuConstants.RES_1280_720: "HD 720p (1280 x 720)",
        QemuConstants.RES_1920_1080: "HD 1080p (1920 x 1080)",
        QemuConstants.RES_2048_1152: "2K (2048 x 1152)",
        QemuConstants.RES_2560_1440: "QHD (2560 x 1440)",
        QemuConstants.RES_3840_2160: "UHD (3840 x 2160)",
        QemuConstants.RES_4096_2160: "4K (4096 x 2160)",
        QemuConstants.RES_5120_2280: "5K (5120 x 2280",
        QemuConstants.RES_6016_3384: "6K (6016 x 3384)"
    ];
    
    static let supportedVMTypes: [String] = [
        QemuConstants.OS_MAC,
        QemuConstants.OS_WIN,
        QemuConstants.OS_LINUX,
        QemuConstants.OS_OTHER
    ]
    
    static let MACHINE_TYPE_MAC99 = "mac99,via=pmu";
    static let MACHINE_TYPE_Q35 = "q35";
    
    static let PC_BIOS = "pc-bios";
    
    static let NETWORK_SUNGEM = "sungem";
    
    static let VGA_VIRTIO = "virtio";
    static let VGA_VMWARE = "vmware";
    
    static let CPU_HOST = "host";
    
    static let ACCEL_HVF = "hvf";
    
    static let USB_TABLET = "usb-tablet";
}
