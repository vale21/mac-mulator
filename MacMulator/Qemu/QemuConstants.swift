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
    static let MEDIATYPE_USB = "usb";
    static let MEDIATYPE_EFI = "efi";
    static let MEDIATYPE_OPENCORE = "opencore";
    
    static let IMAGE_CMD_CREATE = "create";
    static let IMAGE_CMD_INFO = "info";
    static let IMAGE_CMD_RESIZE = "resize";
    static let IMAGE_CMD_CONVERT = "convert";
    static let IMAGE_CMD_VERSION = "--version";
    
    static let FORMAT_QCOW2 = "qcow2";
    static let FORMAT_RAW = "raw";
    static let FORMAT_UNKNOWN = "unknown";
    
    // Virtual Machine constants
    
    static let CD = "CD/DVD";
    static let HD = "Hard Drive";
    static let USB = "USB Drive";
    static let EFI = "EFI Firmware";
    static let NET = "Network";
    
    static let ARG_CD = "d";
    static let ARG_HD = "c";
    static let ARG_NET = "n";
    static let ARG_BOOTLOADER = "menu=on";
    
    static let OS_MAC = "macOS";
    static let OS_WIN = "Windows";
    static let OS_LINUX = "Linux";
    static let OS_OTHER = "Other";
    
    static let SUB_MAC_GENERIC = "Generic macOS";
    static let SUB_MAC_BETA = "Mac OS X Public Beta";
    static let SUB_MAC_CHEETAH = "Mac OS X 10.0.x (Cheetah)";
    static let SUB_MAC_PUMA = "Mac OS X 10.1.x (Puma)";
    static let SUB_MAC_JAGUAR = "Mac OS X 10.2.x (Jaguar)";
    static let SUB_MAC_PANTHER = "Mac OS X 10.3.x (Panther)";
    static let SUB_MAC_TIGER = "Mac OS X 10.4.x (Tiger)";
    static let SUB_MAC_LEOPARD = "Mac OS X 10.5.x (Leopard)";
    static let SUB_MAC_SNOW_LEOPARD = "Mac OS X 10.6.x (Snow Leopard)";
    static let SUB_MAC_LION = "Mac OS X 10.7.x (Lion)";
    static let SUB_MAC_MOUNTAIN_LION = "OS X 10.8.x (Mountain Lion)";
    static let SUB_MAC_MAVERICKS = "OS X 10.9.x (Mavericks)";
    static let SUB_MAC_YOSEMITE = "OS X 10.10.x (Yosemite)";
    static let SUB_MAC_EL_CAPITAN = "OS X 10.11.x (El Capitan)";
    static let SUB_MAC_SIERRA = "macOS 10.12.x (Sierra)";
    static let SUB_MAC_HIGH_SIERRA = "macOS 10.13.x (High Sierra)";
    static let SUB_MAC_MOJAVE = "macOS 10.14.x (Mojave)";
    static let SUB_MAC_CATALINA = "macOS 10.15.x (Catalina)";
    static let SUB_MAC_BIG_SUR = "macOS 11.x (Big Sur)";
    static let SUB_MAC_MONTEREY = "macOS 12.x (Monterey)";
    static let SUB_MAC_OS_9 = "Mac OS 9";
    static let SUB_MAC_OS_8 = "Mac OS 8";
    static let SUB_SYSTEM_7 = "System 7";
    static let SUB_SYSTEM_6 = "System 6";
    static let SUB_SYSTEM_5 = "System 5";
    static let SUB_SYSTEM_4 = "System 4";
    static let SUB_SYSTEM_3 = "System 3";
    static let SUB_SYSTEM_2 = "System 2";
    static let SUB_SYSTEM_1 = "System 1";
    
    static let SUB_WIN_GENERIC = "Generic Windows";
    static let SUB_WINDOWS_11 = "Windows 11";
    static let SUB_WINDOWS_11_ARM = "Windows 11 (ARM)";
    static let SUB_WINDOWS_10 = "Windows 10";
    static let SUB_WINDOWS_10_ARM = "Windows 10 (ARM)";
    static let SUB_WINDOWS_8_1 = "Windows 8.1";
    static let SUB_WINDOWS_8 = "Windows 8";
    static let SUB_WINDOWS_7 = "Windows 7";
    static let SUB_WINDOWS_VISTA = "Windows Vista";
    static let SUB_WINDOWS_XP = "Windows XP";
    static let SUB_WINDOWS_2000 = "Windows 2000";
    static let SUB_WINDOWS_ME = "Windows ME";
    static let SUB_WINDOWS_98 = "Windows 98";
    static let SUB_WINDOWS_NT = "Windows NT";
    static let SUB_WINDOWS_95 = "Windows 95";
    static let SUB_WINDOWS_3 = "Windows 3";
    static let SUB_WINDOWS_2 = "Windows 2";
    static let SUB_WINDOWS_1 = "Windows 1";
    
    static let SUB_LINUX_GENERIC = "Generic Linux (x64)";
    static let SUB_LINUX_GENERIC_ARM = "Generic Linux (ARM)";
    static let SUB_LINUX_GENERIC_PPC = "Generic Linux (PPC)";
    static let SUB_LINUX_GENERIC_RISCV = "Generic Linux (RISC-V)";
    static let SUB_MX_LINUX = "MX Linux";
    static let SUB_LINUX_MINT = "Linux Mint";
    static let SUB_LINUX_MINT_ARM = "Linux Mint (ARM)";
    static let SUB_LINUX_MINT_PPC = "Linux Mint (PPC)";
    static let SUB_DEBIAN = "Debian GNU/Linux";
    static let SUB_DEBIAN_ARM = "Debian GNU/Linux (ARM)";
    static let SUB_DEBIAN_PPC = "Debian GNU/Linux (PPC)";
    static let SUB_UBUNTU = "Ubuntu Linux";
    static let SUB_UBUNTU_ARM = "Ubuntu Linux (ARM)";
    static let SUB_UBUNTU_PPC = "Ubuntu Linux (PPC)";
    static let SUB_OPENSUSE = "openSUSE";
    static let SUB_MANJARO = "Manjaro Linux";
    static let SUB_RED_HAT = "Red Hat Linux";
    static let SUB_SOLUS = "Solus";
    static let SUB_DEEPIN = "Deepin";
    static let SUB_FEDORA = "Fedora";
    static let SUB_ZORIN = "Zorin OS";
    static let SUB_SLACKWARE = "Slackware Linux";
    static let SUB_ELEMENTARY = "Elementary OS";
    static let SUB_CENTOS_LINUX = "CentOS Linux";
    static let SUB_ARCH_LINUX = "Arch Linux";
    static let SUB_REACT_OS = "ReactOS";
    static let SUB_RASPBERRY_OS = "Raspberry Pi OS";
    
    static let SUB_OTHER_GENERIC = "Generic VM";
    static let SUB_OTHER_x64 = "Generic x86_64 VM";
    static let SUB_OTHER_x86 = "Generic x86 VM";
    static let SUB_OTHER_ARM_64 = "Generic ARM 64 VM";
    static let SUB_OTHER_ARM = "Generic ARM VM";
    static let SUB_OTHER_PPC_64 = "Generic PowerPc 64 VM";
    static let SUB_OTHER_PPC = "Generic PowerPc VM";
    static let SUB_OTHER_RISCV_64 = "Generic RISC-V 64 VM";
    static let SUB_OTHER_RISCV = "Generic RISC-V VM";
    static let SUB_OTHER_M68K = "Generic Motorola 68k VM";
    
    static let ICON_MAC_OS_9 = "mac.os.9";
    static let ICON_MAC_CHEETAH = "cheetah";
    static let ICON_MAC_JAGUAR = "jaguar";
    static let ICON_MAC_PANTHER = "panther";
    static let ICON_MAC_TIGER = "tiger";
    static let ICON_MAC_LEOPARD = "leopard";
    static let ICON_MAC_SNOW_LEOPARD = "snow.leopard";
    
    static let ICON_SIERRA = "sierra";
    static let ICON_HIGH_SIERRA = "high.sierra";
    static let ICON_MOJAVE = "mojave";
    static let ICON_CATALINA = "catalina";
    static let ICON_BIG_SUR = "big.sur";
    static let ICON_MONTEREY = "monterey";
    static let ICON_WINDOWS_XP = "windows.xp";
    static let ICON_WINDOWS_VISTA = "windows.vista";
    static let ICON_WINDOWS_7 = "windows.7";
    static let ICON_WINDOWS_8 = "windows.8";
    static let ICON_WINDOWS_8_1 = "windows.8.1";
    static let ICON_WINDOWS_10 = "windows.10";
    static let ICON_MX_LINUX = "mx.linux";
    static let ICON_LINUX_MINT = "linux.mint";
    static let ICON_DEBIAN = "debian";
    static let ICON_UBUNTU = "ubuntu";
    static let ICON_OPENSUSE = "opensuse";
    static let ICON_ARCH_LINUX = "arch.linux";
    static let ICON_MANJARO = "manjaro";
    static let ICON_FEDORA = "fedora";
    
    
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
        ARCH_68K
    ]
    
    static let ALL_ARCHITECTURES_DESC: [String:String] = [
        QemuConstants.ARCH_X64: "Intel/AMD 64bit",
        QemuConstants.ARCH_X86: "Intel/AMD 32bit",
        QemuConstants.ARCH_PPC: "PowerPc 32bit",
        QemuConstants.ARCH_PPC64: "PowerPc 64bit",
        QemuConstants.ARCH_ARM: "ARM",
        QemuConstants.ARCH_ARM64: "ARM 64bit",
        QemuConstants.ARCH_68K: "Motorola 68k"
    ];
    
    static let MAX_CPUS: [String:Int] = [
        ARCH_PPC: 1,
        ARCH_PPC64: 1,
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
    
    // Other
    static let RES_1280_768 = "1280x768x32";
    
    static let ALL_RESOLUTIONS = [
        RES_640_480,
        RES_800_600,
        RES_1024_768,
        RES_1280_1024,
        RES_1600_1200,
        RES_1024_600,
        RES_1280_768,
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
        QemuConstants.RES_1280_768: "1280 x 768",
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
    
    static let vmDefaults = [
        // ["VM Type", "VM Subtype", "default Arch", "default Cpus", "min RAM", "max RAM", "default RAM", "min Disk", "max Disk", "default Disk", "mac_os_x_tiger", "icon", "machine type", "cpu", "hvf", "network"],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_GENERIC, QemuConstants.ARCH_PPC, 1, 256, 3072, 512, 5, 500, 50, QemuConstants.OS_MAC.lowercased(), QemuConstants.MACHINE_TYPE_MAC99_PMU, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_MONTEREY, QemuConstants.ARCH_ARM64, 4, 4096, 32768, 4096, 120, 8192, 250, QemuConstants.ICON_MONTEREY, QemuConstants.MACHINE_TYPE_VIRT, nil, true, nil],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_BIG_SUR, QemuConstants.ARCH_ARM64, 4, 4096, 32768, 4096, 120, 8192, 250, QemuConstants.ICON_BIG_SUR, QemuConstants.MACHINE_TYPE_VIRT, nil, true, nil],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_CATALINA, QemuConstants.ARCH_X64, 2, 2048, 32768, 2048, 120, 8192, 250, QemuConstants.ICON_CATALINA, QemuConstants.MACHINE_TYPE_Q35, nil, true, QemuConstants.NETWORK_VMXNET],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_MOJAVE, QemuConstants.ARCH_X64, 2, 2048, 32768, 2048, 120, 8192, 250, QemuConstants.ICON_MOJAVE, QemuConstants.MACHINE_TYPE_Q35, nil, true, QemuConstants.NETWORK_VMXNET],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_HIGH_SIERRA, QemuConstants.ARCH_X64, 2, 2048, 32768, 2048, 120, 8192, 250, ICON_HIGH_SIERRA, QemuConstants.MACHINE_TYPE_Q35, nil, true, QemuConstants.NETWORK_VMXNET],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_SIERRA, QemuConstants.ARCH_X64, 2, 2048, 16384, 2048, 120, 8192, 250, QemuConstants.ICON_SIERRA, QemuConstants.MACHINE_TYPE_Q35, nil, true, QemuConstants.NETWORK_VMXNET],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_EL_CAPITAN, QemuConstants.ARCH_X64, 2, 2048, 16384, 2048, 120, 8192, 250, QemuConstants.OS_MAC.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, QemuConstants.NETWORK_VMXNET],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_YOSEMITE, QemuConstants.ARCH_X64, 2, 2048, 16384, 2048, 120, 8192, 250, QemuConstants.OS_MAC.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, QemuConstants.NETWORK_VMXNET],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_MAVERICKS, QemuConstants.ARCH_X64, 2, 1024, 16384, 2048, 50, 4096, 120, QemuConstants.OS_MAC.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, QemuConstants.NETWORK_VMXNET],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_MOUNTAIN_LION, QemuConstants.ARCH_X64, 2, 1024, 16384, 1024, 50, 4096, 120, QemuConstants.OS_MAC.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, QemuConstants.NETWORK_VMXNET],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_LION, QemuConstants.ARCH_X64, 2, 1024, 16384, 1024, 50, 4096, 120, QemuConstants.OS_MAC.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, QemuConstants.NETWORK_VMXNET],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_SNOW_LEOPARD, QemuConstants.ARCH_X64, 2, 512, 8192, 1024, 10, 2048, 120, QemuConstants.ICON_MAC_SNOW_LEOPARD, QemuConstants.MACHINE_TYPE_Q35, QemuConstants.CPU_PENRYN, false, QemuConstants.NETWORK_E1000],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_LEOPARD, QemuConstants.ARCH_X86, 2, 512, 3072, 512, 10, 2048, 50, QemuConstants.ICON_MAC_LEOPARD, QemuConstants.MACHINE_TYPE_PC, nil, true, QemuConstants.NETWORK_VIRTIO],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_TIGER, QemuConstants.ARCH_PPC, 1, 256, 3072, 512, 5, 500, 50, QemuConstants.ICON_MAC_TIGER, QemuConstants.MACHINE_TYPE_MAC99_PMU, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_PANTHER, QemuConstants.ARCH_PPC, 1, 128, 2048, 512, 5, 500, 50, QemuConstants.ICON_MAC_PANTHER, QemuConstants.MACHINE_TYPE_MAC99_PMU, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_JAGUAR, QemuConstants.ARCH_PPC, 1, 128, 2048, 256, 5, 500, 50, QemuConstants.ICON_MAC_JAGUAR, QemuConstants.MACHINE_TYPE_MAC99_PMU, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_PUMA, QemuConstants.ARCH_PPC, 1, 128, 2048, 256, 5, 500, 50, QemuConstants.ICON_MAC_CHEETAH, QemuConstants.MACHINE_TYPE_MAC99, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_CHEETAH, QemuConstants.ARCH_PPC, 1, 128, 2048, 256, 5, 500, 50, QemuConstants.ICON_MAC_CHEETAH, QemuConstants.MACHINE_TYPE_MAC99, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_OS_9, QemuConstants.ARCH_PPC, 1, 32, 1024, 64, 5, 500, 30, QemuConstants.ICON_MAC_OS_9, QemuConstants.MACHINE_TYPE_MAC99, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_MAC, QemuConstants.SUB_MAC_OS_8, QemuConstants.ARCH_PPC, 1, 32, 512, 32, 5, 500, 30, QemuConstants.OS_MAC.lowercased(), QemuConstants.MACHINE_TYPE_MAC99, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_MAC, QemuConstants.SUB_SYSTEM_7, QemuConstants.ARCH_68K, 1, 32, 512, 32, 5, 500, 30, QemuConstants.OS_MAC.lowercased(), QemuConstants.MACHINE_TYPE_Q800, nil, true, nil],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WIN_GENERIC, QemuConstants.ARCH_X64, 2, 1024, 32768, 2048, 120, 8192, 250, QemuConstants.OS_WIN.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_11_ARM, QemuConstants.ARCH_ARM64, 4, 2048, 32768, 2048, 250, 8192, 250, QemuConstants.OS_WIN.lowercased(), QemuConstants.MACHINE_TYPE_VIRT, true, QemuConstants.CPU_CORTEX_A72, nil],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_11, QemuConstants.ARCH_X64, 2, 2048, 32768, 2048, 250, 8192, 250, QemuConstants.OS_WIN.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_10_ARM, QemuConstants.ARCH_ARM64, 4, 1024, 32768, 2048, 120, 8192, 250, QemuConstants.ICON_WINDOWS_10, QemuConstants.MACHINE_TYPE_VIRT, QemuConstants.CPU_CORTEX_A72, true, nil],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_10, QemuConstants.ARCH_X64, 2, 1024, 32768, 2048, 120, 8192, 250, QemuConstants.ICON_WINDOWS_10, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_8_1, QemuConstants.ARCH_X64, 2, 1024, 32768, 2048, 120, 8192, 250, QemuConstants.ICON_WINDOWS_8_1, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_8, QemuConstants.ARCH_X64, 2, 1024, 32768, 2048, 120, 8192, 250, QemuConstants.ICON_WINDOWS_8, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_7, QemuConstants.ARCH_X64, 2, 1024, 32768, 2048, 120, 8192, 250, QemuConstants.ICON_WINDOWS_7, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_VISTA, QemuConstants.ARCH_X64, 2, 1024, 32768, 2048, 120, 8192, 250, QemuConstants.ICON_WINDOWS_VISTA, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_XP, QemuConstants.ARCH_X86, 1, 512, 3072, 1024, 120, 4096, 250, QemuConstants.ICON_WINDOWS_XP, QemuConstants.MACHINE_TYPE_PC, nil, true, QemuConstants.NETWORK_VIRTIO],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_2000, QemuConstants.ARCH_X86, 1, 512, 3072, 1024, 120, 4096, 250, QemuConstants.OS_WIN.lowercased(), QemuConstants.MACHINE_TYPE_PC, nil, true, QemuConstants.NETWORK_VIRTIO],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_ME, QemuConstants.ARCH_X86, 1, 256, 2048, 512, 20, 500, 120, QemuConstants.OS_WIN.lowercased(), QemuConstants.MACHINE_TYPE_PC, nil, true, QemuConstants.NETWORK_VIRTIO],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_98, QemuConstants.ARCH_X86, 1, 128, 1024, 256, 5, 500, 50, QemuConstants.OS_WIN.lowercased(), QemuConstants.MACHINE_TYPE_PC, nil, true, QemuConstants.NETWORK_VIRTIO],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_NT, QemuConstants.ARCH_X86, 1, 128, 1024, 256, 5, 500, 50, QemuConstants.OS_WIN.lowercased(), QemuConstants.MACHINE_TYPE_PC, nil, true, QemuConstants.NETWORK_VIRTIO],
        [QemuConstants.OS_WIN, QemuConstants.SUB_WINDOWS_95, QemuConstants.ARCH_X86, 1, 2, 512, 32, 5, 500, 10, QemuConstants.OS_WIN.lowercased(), QemuConstants.MACHINE_TYPE_PC, nil, true, QemuConstants.NETWORK_VIRTIO],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_LINUX_GENERIC, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_LINUX_GENERIC_ARM, QemuConstants.ARCH_ARM64, 128, 32768, 1024, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_VIRT, QemuConstants.CPU_CORTEX_A72, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_LINUX_GENERIC_PPC, QemuConstants.ARCH_PPC, 1, 128, 2048, 512, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_MAC99_PMU, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_MX_LINUX, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.ICON_MX_LINUX, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_LINUX_MINT, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.ICON_LINUX_MINT, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_LINUX_MINT_ARM, QemuConstants.ARCH_ARM64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.ICON_LINUX_MINT, QemuConstants.MACHINE_TYPE_VIRT, QemuConstants.CPU_CORTEX_A72, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_LINUX_MINT_PPC, QemuConstants.ARCH_PPC, 1, 128, 2048, 512, 30, 8192, 250, QemuConstants.ICON_LINUX_MINT, QemuConstants.MACHINE_TYPE_MAC99_PMU, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_DEBIAN, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.ICON_DEBIAN, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_DEBIAN_ARM, QemuConstants.ARCH_ARM64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.ICON_DEBIAN, QemuConstants.MACHINE_TYPE_VIRT, QemuConstants.CPU_CORTEX_A72, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_DEBIAN_PPC, QemuConstants.ARCH_PPC, 1, 128, 2048, 512, 30, 8192, 250, QemuConstants.ICON_DEBIAN, QemuConstants.MACHINE_TYPE_MAC99_PMU, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_UBUNTU, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.ICON_UBUNTU, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_UBUNTU_ARM, QemuConstants.ARCH_ARM64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.ICON_UBUNTU, QemuConstants.MACHINE_TYPE_VIRT, QemuConstants.CPU_CORTEX_A72, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_UBUNTU_PPC, QemuConstants.ARCH_PPC, 1, 128, 2048, 512, 30, 8192, 250, QemuConstants.ICON_UBUNTU, QemuConstants.MACHINE_TYPE_MAC99_PMU, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_OPENSUSE, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.ICON_OPENSUSE, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_ARCH_LINUX, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.ICON_ARCH_LINUX, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_MANJARO, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.ICON_MANJARO, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_FEDORA, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.ICON_FEDORA, QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_RED_HAT, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_CENTOS_LINUX, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_SOLUS, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_DEEPIN, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_ZORIN, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_SLACKWARE, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_ELEMENTARY, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_REACT_OS, QemuConstants.ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_LINUX, QemuConstants.SUB_RASPBERRY_OS, QemuConstants.ARCH_ARM64, 2, 128, 32768, 1024, 30, 8192, 250, QemuConstants.OS_LINUX.lowercased(), QemuConstants.MACHINE_TYPE_VIRT, QemuConstants.CPU_CORTEX_A72, true, nil],
        [QemuConstants.OS_OTHER, QemuConstants.SUB_OTHER_GENERIC, QemuConstants.ARCH_X64, 2, 1, 32768, 2048, 1, 8192, 120, QemuConstants.OS_OTHER.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_OTHER, QemuConstants.SUB_OTHER_x64, QemuConstants.ARCH_X64, 2, 1, 32768, 2048, 1, 8192, 120, QemuConstants.OS_OTHER.lowercased(), QemuConstants.MACHINE_TYPE_Q35, nil, true, nil],
        [QemuConstants.OS_OTHER, QemuConstants.SUB_OTHER_x86, QemuConstants.ARCH_X86, 1, 1, 3072, 512, 1, 8192, 120, QemuConstants.OS_OTHER.lowercased(), QemuConstants.MACHINE_TYPE_PC, nil, true, QemuConstants.NETWORK_VIRTIO],
        [QemuConstants.OS_OTHER, QemuConstants.SUB_OTHER_ARM_64, QemuConstants.ARCH_ARM64, 2, 1, 32768, 2048, 1, 8192, 120, QemuConstants.OS_OTHER.lowercased(), QemuConstants.MACHINE_TYPE_VIRT, QemuConstants.CPU_CORTEX_A72, true, nil],
        [QemuConstants.OS_OTHER, QemuConstants.SUB_OTHER_ARM, QemuConstants.ARCH_ARM, 2, 1, 3072, 512, 1, 8192, 120, QemuConstants.OS_OTHER.lowercased(), QemuConstants.MACHINE_TYPE_VIRT, QemuConstants.CPU_ARM1176, true, nil],
        [QemuConstants.OS_OTHER, QemuConstants.SUB_OTHER_PPC_64, QemuConstants.ARCH_PPC64, 2, 1, 32768, 2048, 1, 8192, 120, QemuConstants.OS_OTHER.lowercased(), QemuConstants.MACHINE_TYPE_MAC99_PMU, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_OTHER, QemuConstants.SUB_OTHER_PPC, QemuConstants.ARCH_PPC, 2, 1, 3072, 512, 1, 8192, 120, QemuConstants.OS_OTHER.lowercased(), QemuConstants.MACHINE_TYPE_MAC99_PMU, nil, true, QemuConstants.NETWORK_SUNGEM],
        [QemuConstants.OS_OTHER, QemuConstants.SUB_OTHER_M68K, QemuConstants.ARCH_68K, 1, 1, 512, 16, 1, 50, 5, QemuConstants.OS_OTHER.lowercased(), QemuConstants.MACHINE_TYPE_Q800, nil, true, nil]
    ]
    
    static let HOST_I386 = "i386";
    static let HOST_X86_64 = "x86_64";
    static let HOST_ARM64 = "arm64";
    
    static let MACHINE_TYPE_MAC99 = "mac99";
    static let MACHINE_TYPE_MAC99_PMU = "mac99,via=pmu";
    static let MACHINE_TYPE_PSERIES = "pseries";
    static let MACHINE_TYPE_VERSATILEPB = "versatilepb";
    static let MACHINE_TYPE_Q35 = "q35";
    static let MACHINE_TYPE_PC = "pc";
    static let MACHINE_TYPE_VIRT = "virt,highmem=off";
    static let MACHINE_TYPE_Q800 = "q800";
    
    static let SERIAL_STDIO = "stdio";
    
    static let PC_BIOS = "pc-bios";
    
    static let NETWORK_SUNGEM = "sungem";
    static let NETWORK_VIRTIO = "virtio-net";
    static let NETWORK_VMXNET = "vmxnet3";
    static let NETWORK_E1000 = "e1000";
    
    static let VGA_VIRTIO = "virtio";
    static let VGA_VMWARE = "vmware";
    
    static let DISPLAY_DEFAULT = "default";
    
    static let CPU_HOST = "host";
    static let CPU_PENRYN_SSE = "Penryn,+ssse3,+sse4.1,+sse4.2"
    static let CPU_PENRYN = "Penryn"
    static let CPU_QEMU64 = "qemu64";
    static let CPU_CORTEX_A72 = "cortex-a72";
    static let CPU_ARM1176 = "arm1176"
    
    static let ACCEL_HVF = "hvf";
    static let ACCEL_TCG = "tcg,thread=multi,tb-size=1024";
    
    static let USB_KEYBOARD = "usb-kbd";
    static let USB_TABLET = "usb-tablet";
    static let QEMU_XHCI = "qemu-xhci";
    static let APPLE_SMC = "isa-applesmc,osk=\"ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc\""
    static let VIRTIO_GPU_PCI = "virtio-gpu-pci";
    
    static let SOUND_HDA = "intel-hda"
    static let SOUND_HDA_DUPLEX = "hda-duplex"
    static let SOUND_AC97 = "AC97"
    
    static let OPENCORE_MODERN = "OPENCORE_MODERN";
    static let OPENCORE_LEGACY = "OPENCORE_LEGACY";
}
