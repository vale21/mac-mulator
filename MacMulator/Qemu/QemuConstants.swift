//
//  swift
//  MacMulator
//
//  Created by Vale on 05/02/21.
//

import Foundation

class QemuConstants {

    // Disk image constants
    
    static let MEDIATYPE_DISK = "disk";
    static let MEDIATYPE_NVME = "nvme";
    static let MEDIATYPE_CDROM = "cdrom";
    static let MEDIATYPE_USB = "usb";
    static let MEDIATYPE_EFI = "efi";
    static let MEDIATYPE_NVRAM = "nvram";
    static let MEDIATYPE_OPENCORE = "opencore";
    static let MEDIATYPE_IPSW = "ipsw";
    
    static let IMAGE_CMD_CREATE = "create";
    static let IMAGE_CMD_INFO = "info";
    static let IMAGE_CMD_RESIZE = "resize";
    static let IMAGE_CMD_CONVERT = "convert";
    static let IMAGE_CMD_VERSION = "--version";
    
    static let FORMAT_QCOW2 = "qcow2";
    static let FORMAT_RAW = "raw";
    static let FORMAT_UNKNOWN = "unknown";
    static let FORMAT_VHDX = "vhdx";
    
    // Virtual Machine constants
    
    static let CD = "CD/DVD";
    static let HD = "Hard Drive";
    static let USB = "USB Drive";
    static let IPSW = "IPSW Install Image";
    static let EFI = "EFI Firmware";
    static let NET = "Network";
    static let NVRAM = "Nvram"
    static let NVME = "NVMe Drive"
    
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
    static let SUB_MAC_VENTURA = "macOS 13.x (Ventura)";
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
    static let SUB_WINDOWS_10 = "Windows 10";
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
    
    static let SUB_LINUX_GENERIC = "Generic Linux";
    static let SUB_MX_LINUX = "MX Linux";
    static let SUB_LINUX_MINT = "Linux Mint";
    static let SUB_DEBIAN = "Debian GNU/Linux";
    static let SUB_UBUNTU = "Ubuntu Linux";
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
    static let ICON_LION = "lion";
    static let ICON_MOUNTAIN_LION = "mountain.lion";
    static let ICON_MAVERICKS = "mavericks";
    static let ICON_YOSEMITE = "yosemite";
    static let ICON_EL_CAPITAN = "el.capitan";
    static let ICON_SIERRA = "sierra";
    static let ICON_HIGH_SIERRA = "high.sierra";
    static let ICON_MOJAVE = "mojave";
    static let ICON_CATALINA = "catalina";
    static let ICON_BIG_SUR = "big.sur";
    static let ICON_MONTEREY = "monterey";
    static let ICON_VENTURA = "ventura";
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
        ARCH_X64: "Intel/AMD 64bit",
        ARCH_X86: "Intel/AMD 32bit",
        ARCH_PPC: "PowerPc 32bit",
        ARCH_PPC64: "PowerPc 64bit",
        ARCH_ARM: "ARM",
        ARCH_ARM64: "ARM 64bit",
        ARCH_68K: "Motorola 68k"
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
        RES_640_480: "640 x 480",
        RES_800_600: "800 x 600",
        RES_1024_768: "1024 x 768",
        RES_1280_1024: "1280 x 1024",
        RES_1600_1200: "1600 x 1200",
        RES_1024_600: "1024 x 600",
        RES_1280_768: "1280 x 768",
        RES_1280_800: "1280 x 800",
        RES_1440_900: "1440 x 900",
        RES_1680_1050: "1680 x 1050",
        RES_1920_1200: "1920 x 1200",
        RES_1280_720: "HD 720p (1280 x 720)",
        RES_1920_1080: "HD 1080p (1920 x 1080)",
        RES_2048_1152: "2K (2048 x 1152)",
        RES_2560_1440: "QHD (2560 x 1440)",
        RES_3840_2160: "UHD (3840 x 2160)",
        RES_4096_2160: "4K (4096 x 2160)",
        RES_5120_2280: "5K (5120 x 2280",
        RES_6016_3384: "6K (6016 x 3384)"
    ];
    
    static let supportedVMTypes: [String] = [
        OS_MAC,
        OS_WIN,
        OS_LINUX,
        OS_OTHER
    ]
    
    static let ALL_NETWORK_ADAPTERS = [
       NETWORK_E1000,
       NETWORK_E1000_82544GC,
       NETWORK_E1000_82545EM,
       NETWORK_E1000E,
       NETWORK_I82550,
       NETWORK_I82551,
       NETWORK_I82557A,
       NETWORK_I82557B,
       NETWORK_I82557C,
       NETWORK_I82558A,
       NETWORK_I82558B,
       NETWORK_I82559A,
       NETWORK_I82559B,
       NETWORK_I82559C,
       NETWORK_I82559ER,
       NETWORK_I82562,
       NETWORK_I82801,
       NETWORK_NE2K_ISA,
       NETWORK_NE2K_PCI,
       NETWORK_PCNET,
       NETWORK_ROCKER,
       NETWORK_RTL8139,
       NETWORK_SUNGEM,
       NETWORK_TULIP,
       NETWORK_USB_NET,
       NETWORK_VIRTIO_NET_DEVICE,
       NETWORK_VIRTIO_NET_PCI,
       NETWORK_VIRTIO_NET_PCI_NON_TRANSITIONAL,
       NETWORK_VIRTIO_NET_PCI_TRANSITIONAL,
       NETWORK_VMXNET3
    ]
    
    static let ALL_NETWORK_ADAPTERS_DESC: [String:String] = [
        NETWORK_E1000 : "Intel Gigabit Ethernet",
        NETWORK_E1000_82544GC: "Intel e1000 (82544GC)",
        NETWORK_E1000_82545EM: "Intel e1000 (82545EM)",
        NETWORK_E1000E: "Intel 82574L GbE Controller",
        NETWORK_I82550: "Intel i82550 10/100 Ethernet",
        NETWORK_I82551: "Intel i82551 10/100 Ethernet",
        NETWORK_I82557A: "Intel i82557A 10/100 Ethernet",
        NETWORK_I82557B: "Intel i82557B 10/100 Ethernet",
        NETWORK_I82557C: "Intel i82557C 10/100 Ethernet",
        NETWORK_I82558A: "Intel i82558A 10/100 Ethernet",
        NETWORK_I82558B: "Intel i82558B 10/100 Ethernet",
        NETWORK_I82559A: "Intel i82559A 10/100 Ethernet",
        NETWORK_I82559B: "Intel i82559B 10/100 Ethernet",
        NETWORK_I82559C: "Intel i82559C 10/100 Ethernet",
        NETWORK_I82559ER: "Intel i82559ER 10/100 Ethernet",
        NETWORK_I82562: "Intel i82562 Ethernet",
        NETWORK_I82801: "Intel i82801 Ethernet",
        NETWORK_NE2K_ISA: "NE2000, bus ISA",
        NETWORK_NE2K_PCI: "NE2000, bus PCI",
        NETWORK_PCNET: "AMD PCnet FAST III Ethernet",
        NETWORK_ROCKER: "Rocker Device",
        NETWORK_RTL8139: "Realtek 8139 10/100 Ethernet",
        NETWORK_SUNGEM: "SunGEM NIC",
        NETWORK_TULIP: "DEC21040 \"tulip\"",
        NETWORK_USB_NET: "USB attched Ethernet",
        NETWORK_VIRTIO_NET_DEVICE: "VirtIO network device",
        NETWORK_VIRTIO_NET_PCI: "VirtIO network device (PCI)",
        NETWORK_VIRTIO_NET_PCI_NON_TRANSITIONAL: "VirtIO network device (non-transitional)",
        NETWORK_VIRTIO_NET_PCI_TRANSITIONAL: "VirtIO network device (transitional)",
        NETWORK_VMXNET3: "VMWare Paravirtualized Ethernet"
    ];
    
    static let vmDefaults = [
        // ["VM Type", "VM Subtype", "default Arch", "default Cpus", "min RAM", "max RAM", "default RAM", "min Disk", "max Disk", "default Disk", "icon", "machine type", "cpu", "hvf", "network", "sound"],
        [OS_MAC, SUB_MAC_GENERIC, ARCH_PPC, 1, 256, 3072, 512, 5, 500, 50, OS_MAC.lowercased(), MACHINE_TYPE_MAC99_PMU, nil, false, NETWORK_SUNGEM, nil],
        [OS_MAC, SUB_MAC_VENTURA, Utils.getPreferredArchitecture(), 6, 4096, 32768, 4096, 60, 8192, 120, ICON_VENTURA, Utils.getPreferredMachineType(), nil, true, NETWORK_VMXNET3, nil],
        [OS_MAC, SUB_MAC_MONTEREY, Utils.getPreferredArchitecture(), 6, 4096, 32768, 4096, 60, 8192, 120, ICON_MONTEREY, Utils.getPreferredMachineType(), nil, true, NETWORK_VMXNET3, nil],
        [OS_MAC, SUB_MAC_BIG_SUR, ARCH_X64, 4, 4096, 32768, 4096, 120, 8192, 250, ICON_BIG_SUR, MACHINE_TYPE_Q35, nil, true, NETWORK_VMXNET3, nil],
        [OS_MAC, SUB_MAC_CATALINA, ARCH_X64, 4, 2048, 32768, 4096, 120, 8192, 250, ICON_CATALINA, MACHINE_TYPE_Q35, nil, true, NETWORK_VMXNET3, nil],
        [OS_MAC, SUB_MAC_MOJAVE, ARCH_X64, 4, 2048, 32768, 4096, 120, 8192, 250, ICON_MOJAVE, MACHINE_TYPE_Q35, nil, true, NETWORK_VMXNET3, nil],
        [OS_MAC, SUB_MAC_HIGH_SIERRA, ARCH_X64, 4, 2048, 32768, 4096, 120, 8192, 250, ICON_HIGH_SIERRA, MACHINE_TYPE_Q35, nil, true, NETWORK_VMXNET3, nil],
        [OS_MAC, SUB_MAC_SIERRA, ARCH_X64, 4, 2048, 16384, 4096, 120, 8192, 250, ICON_SIERRA, MACHINE_TYPE_Q35, CPU_PENRYN_SSE, true, NETWORK_VMXNET3, nil],
        [OS_MAC, SUB_MAC_EL_CAPITAN, ARCH_X64, 4, 2048, 16384, 4096, 120, 8192, 250, ICON_EL_CAPITAN, MACHINE_TYPE_Q35, CPU_PENRYN, true, NETWORK_VMXNET3, nil],
        [OS_MAC, SUB_MAC_YOSEMITE, ARCH_X64, 4, 2048, 16384, 4096, 120, 8192, 250, ICON_YOSEMITE, MACHINE_TYPE_Q35, CPU_PENRYN, false, NETWORK_VMXNET3, nil],
        [OS_MAC, SUB_MAC_MAVERICKS, ARCH_X64, 4, 2048, 16384, 4096, 50, 4096, 120, ICON_MAVERICKS, MACHINE_TYPE_Q35, CPU_PENRYN, false, NETWORK_E1000_82545EM, nil],
        [OS_MAC, SUB_MAC_MOUNTAIN_LION, ARCH_X64, 4, 2048, 16384, 4096, 50, 4096, 120, ICON_MOUNTAIN_LION, MACHINE_TYPE_Q35, CPU_PENRYN, false, NETWORK_E1000, nil],
        [OS_MAC, SUB_MAC_LION, ARCH_X64, 4, 2048, 16384, 4096, 50, 4096, 120, ICON_LION, MACHINE_TYPE_Q35, CPU_PENRYN, false, NETWORK_E1000, nil],
        [OS_MAC, SUB_MAC_SNOW_LEOPARD, ARCH_X64, 2, 512, 8192, 1024, 10, 2048, 120, ICON_MAC_SNOW_LEOPARD, MACHINE_TYPE_Q35, CPU_PENRYN, false, NETWORK_E1000, nil],
        [OS_MAC, SUB_MAC_LEOPARD, ARCH_PPC, 1, 256, 3072, 512, 5, 500, 50, ICON_MAC_LEOPARD, MACHINE_TYPE_MAC99_PMU, nil, false, NETWORK_SUNGEM, nil],
        [OS_MAC, SUB_MAC_TIGER, ARCH_PPC, 1, 256, 3072, 512, 5, 500, 50, ICON_MAC_TIGER, MACHINE_TYPE_MAC99_PMU, nil, false, NETWORK_SUNGEM, nil],
        [OS_MAC, SUB_MAC_PANTHER, ARCH_PPC, 1, 128, 2048, 512, 5, 500, 50, ICON_MAC_PANTHER, MACHINE_TYPE_MAC99_PMU, nil, false, NETWORK_SUNGEM, nil],
        [OS_MAC, SUB_MAC_JAGUAR, ARCH_PPC, 1, 128, 2048, 256, 5, 500, 50, ICON_MAC_JAGUAR, MACHINE_TYPE_MAC99_PMU, nil, false, NETWORK_SUNGEM, nil],
        [OS_MAC, SUB_MAC_PUMA, ARCH_PPC, 1, 128, 2048, 256, 5, 500, 50, ICON_MAC_CHEETAH, MACHINE_TYPE_MAC99, nil, false, NETWORK_SUNGEM, nil],
        [OS_MAC, SUB_MAC_CHEETAH, ARCH_PPC, 1, 128, 2048, 256, 5, 500, 50, ICON_MAC_CHEETAH, MACHINE_TYPE_MAC99, nil, false, NETWORK_SUNGEM, nil],
        [OS_MAC, SUB_MAC_OS_9, ARCH_PPC, 1, 32, 1024, 64, 5, 500, 30, ICON_MAC_OS_9, MACHINE_TYPE_MAC99, nil, false, NETWORK_SUNGEM, nil],
        [OS_MAC, SUB_MAC_OS_8, ARCH_PPC, 1, 32, 512, 32, 5, 500, 30, OS_MAC.lowercased(), MACHINE_TYPE_MAC99, nil, false, NETWORK_SUNGEM, nil],
        [OS_MAC, SUB_SYSTEM_7, ARCH_68K, 1, 32, 512, 32, 5, 500, 30, OS_MAC.lowercased(), MACHINE_TYPE_Q800, nil, false, nil, nil],
        [OS_WIN, SUB_WIN_GENERIC, ARCH_X64, 2, 1024, 32768, 2048, 120, 8192, 250, OS_WIN.lowercased(), MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_WIN, SUB_WINDOWS_10, Utils.getPreferredArchitecture(), 2, 1024, 32768, 2048, 120, 8192, 250, ICON_WINDOWS_10, Utils.getPreferredMachineType(), Utils.getPreferredCPU(), true, NETWORK_E1000, nil],
        [OS_WIN, SUB_WINDOWS_8_1, ARCH_X64, 2, 1024, 32768, 2048, 120, 8192, 250, ICON_WINDOWS_8_1, MACHINE_TYPE_Q35, CPU_IVY_BRIDGE, true, NETWORK_E1000, nil],
        [OS_WIN, SUB_WINDOWS_8, ARCH_X64, 2, 1024, 32768, 2048, 120, 8192, 250, ICON_WINDOWS_8, MACHINE_TYPE_Q35, CPU_IVY_BRIDGE, true, NETWORK_E1000, nil],
        [OS_WIN, SUB_WINDOWS_7, ARCH_X64, 2, 1024, 32768, 2048, 120, 8192, 250, ICON_WINDOWS_7, MACHINE_TYPE_Q35, CPU_IVY_BRIDGE, true, NETWORK_E1000, nil],
        [OS_WIN, SUB_WINDOWS_VISTA, ARCH_X64, 2, 1024, 32768, 2048, 120, 8192, 250, ICON_WINDOWS_VISTA, MACHINE_TYPE_Q35, CPU_PENRYN, true, NETWORK_E1000, SOUND_AC97],
        [OS_WIN, SUB_WINDOWS_XP, ARCH_X86, 1, 512, 3072, 1024, 120, 4096, 250, ICON_WINDOWS_XP, MACHINE_TYPE_PC, nil, false, NETWORK_RTL8139, SOUND_AC97],
        [OS_WIN, SUB_WINDOWS_2000, ARCH_X86, 1, 512, 3072, 1024, 120, 4096, 250, OS_WIN.lowercased(), MACHINE_TYPE_PC, nil, false, NETWORK_VIRTIO_NET_PCI, SOUND_AC97],
        [OS_WIN, SUB_WINDOWS_ME, ARCH_X86, 1, 256, 2048, 512, 20, 500, 120, OS_WIN.lowercased(), MACHINE_TYPE_PC, nil, false, NETWORK_VIRTIO_NET_PCI, SOUND_AC97],
        [OS_WIN, SUB_WINDOWS_98, ARCH_X86, 1, 128, 1024, 256, 5, 500, 50, OS_WIN.lowercased(), MACHINE_TYPE_PC, nil, false, NETWORK_VIRTIO_NET_PCI, nil],
        [OS_WIN, SUB_WINDOWS_NT, ARCH_X86, 1, 128, 1024, 256, 5, 500, 50, OS_WIN.lowercased(), MACHINE_TYPE_PC, nil, false, NETWORK_VIRTIO_NET_PCI, nil],
        [OS_WIN, SUB_WINDOWS_95, ARCH_X86, 1, 2, 512, 32, 5, 500, 10, OS_WIN.lowercased(), MACHINE_TYPE_PC, nil, false, NETWORK_VIRTIO_NET_PCI, nil],
        [OS_LINUX, SUB_LINUX_GENERIC, Utils.getPreferredArchitecture(), 2, 128, 32768, 1024, 30, 8192, 250, OS_LINUX.lowercased(), Utils.getPreferredMachineType(), nil, true, nil, nil],
        [OS_LINUX, SUB_MX_LINUX, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, ICON_MX_LINUX, MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_LINUX_MINT, Utils.getPreferredArchitecture(), 2, 128, 32768, 1024, 30, 8192, 250, ICON_LINUX_MINT, Utils.getPreferredMachineType(), nil, true, nil, nil],
        [OS_LINUX, SUB_DEBIAN, Utils.getPreferredArchitecture(), 2, 128, 32768, 1024, 30, 8192, 250, ICON_DEBIAN, Utils.getPreferredMachineType(), nil, true, nil, nil],
        [OS_LINUX, SUB_UBUNTU, Utils.getPreferredArchitecture(), 2, 128, 32768, 1024, 30, 8192, 250, ICON_UBUNTU, Utils.getPreferredMachineType(), nil, true, nil, nil],
        [OS_LINUX, SUB_OPENSUSE, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, ICON_OPENSUSE, MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_ARCH_LINUX, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, ICON_ARCH_LINUX, MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_MANJARO, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, ICON_MANJARO, MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_FEDORA, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, ICON_FEDORA, MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_RED_HAT, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, OS_LINUX.lowercased(), MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_CENTOS_LINUX, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, OS_LINUX.lowercased(), MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_SOLUS, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, OS_LINUX.lowercased(), MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_DEEPIN, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, OS_LINUX.lowercased(), MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_ZORIN, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, OS_LINUX.lowercased(), MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_SLACKWARE, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, OS_LINUX.lowercased(), MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_ELEMENTARY, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, OS_LINUX.lowercased(), MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_REACT_OS, ARCH_X64, 2, 128, 32768, 1024, 30, 8192, 250, OS_LINUX.lowercased(), MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_LINUX, SUB_RASPBERRY_OS, ARCH_ARM64, 2, 128, 32768, 1024, 30, 8192, 250, OS_LINUX.lowercased(), MACHINE_TYPE_VIRT_HIGHMEM, CPU_MAX, true, nil, nil],
        [OS_OTHER, SUB_OTHER_GENERIC, ARCH_X64, 2, 1, 32768, 2048, 1, 8192, 120, OS_OTHER.lowercased(), MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_OTHER, SUB_OTHER_x64, ARCH_X64, 2, 1, 32768, 2048, 1, 8192, 120, OS_OTHER.lowercased(), MACHINE_TYPE_Q35, nil, true, nil, nil],
        [OS_OTHER, SUB_OTHER_x86, ARCH_X86, 1, 1, 3072, 512, 1, 8192, 120, OS_OTHER.lowercased(), MACHINE_TYPE_PC, nil, true, NETWORK_VIRTIO_NET_PCI, nil],
        [OS_OTHER, SUB_OTHER_ARM_64, ARCH_ARM64, 2, 1, 32768, 2048, 1, 8192, 120, OS_OTHER.lowercased(), MACHINE_TYPE_VIRT_HIGHMEM, CPU_MAX, true, nil, nil],
        [OS_OTHER, SUB_OTHER_ARM, ARCH_ARM, 2, 1, 3072, 512, 1, 8192, 120, OS_OTHER.lowercased(), MACHINE_TYPE_VIRT_HIGHMEM, CPU_ARM1176, false, nil, nil],
        [OS_OTHER, SUB_OTHER_PPC_64, ARCH_PPC64, 2, 1, 32768, 2048, 1, 8192, 120, OS_OTHER.lowercased(), MACHINE_TYPE_MAC99_PMU, nil, false, NETWORK_SUNGEM, nil],
        [OS_OTHER, SUB_OTHER_PPC, ARCH_PPC, 2, 1, 3072, 512, 1, 8192, 120, OS_OTHER.lowercased(), MACHINE_TYPE_MAC99_PMU, nil, false, NETWORK_SUNGEM, nil],
        [OS_OTHER, SUB_OTHER_M68K, ARCH_68K, 1, 1, 512, 16, 1, 50, 5, OS_OTHER.lowercased(), MACHINE_TYPE_Q800, nil, false, nil, nil]
    ]
    
    static let HOST_I386 = "i386";
    static let HOST_X86_64 = "x86_64";
    static let HOST_ARM = "arm";
    static let HOST_ARM64 = "arm64";
    static let HOST_PPC = "PowerPC";
    static let HOST_PPC64 = "PowerPC_64";
    static let HOST_RISCV32 = "RISCV-32";
    static let HOST_RISCV64 = "RISCV-64";
    static let HOST_68K = "m68k";
    
    
    static let MACHINE_TYPE_MAC99 = "mac99";
    static let MACHINE_TYPE_MAC99_PMU = "mac99,via=pmu";
    static let MACHINE_TYPE_PSERIES = "pseries";
    static let MACHINE_TYPE_VERSATILEPB = "versatilepb";
    static let MACHINE_TYPE_Q35 = "q35";
    static let MACHINE_TYPE_PC = "pc";
    static let MACHINE_TYPE_VIRT = "virt,highmem=no";
    static let MACHINE_TYPE_VIRT_HIGHMEM = "virt,highmem=on";
    static let MACHINE_TYPE_Q800 = "q800";
    
    static let SERIAL_STDIO = "stdio";
    
    static let PC_BIOS = "pc-bios";
    
    static let NETWORK_E1000 = "e1000";
    static let NETWORK_E1000_82544GC = "e1000-82544gc";
    static let NETWORK_E1000_82545EM = "e1000-82545em";
    static let NETWORK_E1000E = "e1000e";
    static let NETWORK_I82550 = "i82550";
    static let NETWORK_I82551 = "i82551";
    static let NETWORK_I82557A = "i82557a"
    static let NETWORK_I82557B = "i82557b"
    static let NETWORK_I82557C = "i82557c"
    static let NETWORK_I82558A = "i82558a"
    static let NETWORK_I82558B = "i82558b"
    static let NETWORK_I82559A = "i82559a"
    static let NETWORK_I82559B = "i82559b"
    static let NETWORK_I82559C = "i82559c"
    static let NETWORK_I82559ER = "i82559er"
    static let NETWORK_I82562 = "i82562"
    static let NETWORK_I82801 = "i82801"
    static let NETWORK_NE2K_ISA = "ne2k_isa"
    static let NETWORK_NE2K_PCI = "ne2k_pci"
    static let NETWORK_PCNET = "pcnet"
    static let NETWORK_ROCKER = "rocker"
    static let NETWORK_RTL8139 = "rtl8139"
    static let NETWORK_SUNGEM = "sungem";
    static let NETWORK_TULIP = "tulip"
    static let NETWORK_USB_NET = "usb-net"
    static let NETWORK_VIRTIO_NET_DEVICE = "virtio-net-device";
    static let NETWORK_VIRTIO_NET_PCI = "virtio-net-pci"
    static let NETWORK_VIRTIO_NET_PCI_NON_TRANSITIONAL = "virtio-net-pci-non-transitional"
    static let NETWORK_VIRTIO_NET_PCI_TRANSITIONAL = "virtio-net-pci-transitional"
    static let NETWORK_VMXNET3 = "vmxnet3";
    
    
    
    static let VGA_VIRTIO = "virtio";
    static let VGA_VMWARE = "vmware";
    
    static let DISPLAY_DEFAULT = "default";
    
    static let CPU_HOST = "host";
    static let CPU_MAX = "max";
    static let CPU_PENRYN_SSE = "Penryn,+ssse3,+sse4.1,+sse4.2"
    static let CPU_PENRYN = "Penryn"
    static let CPU_SANDY_BRIDGE = "SandyBridge"
    static let CPU_IVY_BRIDGE = "IvyBridge"
    static let CPU_SKYLAKE_CLIENT = "Skylake-Client"
    static let CPU_QEMU64 = "qemu64";
    static let CPU_CORTEX_A72 = "cortex-a72";
    static let CPU_ARM1176 = "arm1176"
    
    static let ACCEL_HVF = "hvf";
    static let ACCEL_TCG = "tcg,thread=multi,tb-size=1024";
    
    static let USB_KEYBOARD = "usb-kbd";
    static let USB_TABLET = "usb-tablet";
    static let QEMU_XHCI = "qemu-xhci";
    static let RAMFB = "ramfb";
    static let APPLE_SMC = "isa-applesmc,osk=\"ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc\""
    static let VIRTIO_GPU_PCI = "virtio-gpu-pci";
    
    static let SOUND_HDA = "intel-hda"
    static let SOUND_HDA_DUPLEX = "hda-duplex"
    static let SOUND_AC97 = "AC97"
    
    static let OPENCORE_MODERN = "OPENCORE_MODERN";
    static let OPENCORE_LEGACY = "OPENCORE_LEGACY";
}
