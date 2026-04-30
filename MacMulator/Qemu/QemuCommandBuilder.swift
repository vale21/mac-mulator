//
//  QemuCommandBuilder.swift
//  MacMulator
//
//  Created by Vale on 05/02/21.
//

import Foundation

class QemuCommandBuilder {
    var qemuPath: String
    var executable: String
    var addQmpString: Bool?
    var showCursor: Bool?
    var serial: String?
    var bios: String?
    var cpus: Int?
    var accel: String?
    var vga: String?
    var display: String?
    var enable3d: Bool?
    var cpu: String?
    var usb: Bool?
    var device: [String] = []
    var bootArg: String?
    var machine: String?
    var memory: Int32?
    var graphics: String?
    var autoBoot: Bool?
    var vgaEnabled: Bool?
    var sound: [String] = []
    var efi: String?
    var efiSecure: String?
    var efiVars: String?
    var globalClause: String?
    var drives: [String] = []
    var network: String?
    var portMappings: [PortMapping] = []
    var managementPort: Int32?
    var nic: String?
    var tpmPath: String?
    var tpmDevice: String?
    var rtcEnabled: Bool = true
    var logging: String?

    init(qemuPath: String, architecture: String) {
        self.qemuPath = qemuPath
        executable = architecture
    }

    func withShowCursor(_ showCursor: Bool) -> QemuCommandBuilder {
        self.showCursor = showCursor
        return self
    }

    func withSerial(_ serial: String?) -> QemuCommandBuilder {
        self.serial = serial
        return self
    }

    func withBios(_ bios: String?) -> QemuCommandBuilder {
        self.bios = bios
        return self
    }

    func withCpus(_ cpus: Int?) -> QemuCommandBuilder {
        self.cpus = cpus
        return self
    }

    func withAccel(_ accel: String?) -> QemuCommandBuilder {
        self.accel = accel
        return self
    }

    func withVga(_ vga: String?) -> QemuCommandBuilder {
        self.vga = vga
        return self
    }

    func withDisplay(_ display: String?) -> QemuCommandBuilder {
        self.display = display
        return self
    }

    func withEnable3D(_ enable3D: Bool) -> QemuCommandBuilder {
        enable3d = enable3D
        return self
    }

    func withCpu(_ cpu: String?) -> QemuCommandBuilder {
        self.cpu = cpu
        return self
    }

    func withUsb(_ usb: Bool) -> QemuCommandBuilder {
        self.usb = usb
        return self
    }

    func withDevice(_ device: String?) -> QemuCommandBuilder {
        if let newDevice = device {
            self.device.append(newDevice)
        }
        return self
    }

    func withBootArg(_ bootArg: String?) -> QemuCommandBuilder {
        self.bootArg = bootArg
        return self
    }

    func withMachine(_ machine: String?, _ options: [String]) -> QemuCommandBuilder {
        self.machine = machine
        if !options.isEmpty {
            let optString = options.joined(separator: ",")
            if let machine = self.machine {
                self.machine = machine + "," + optString
            }
        }
        return self
    }

    func withMemory(_ memory: Int32?) -> QemuCommandBuilder {
        self.memory = memory
        return self
    }

    func withGraphics(_ graphics: String?) -> QemuCommandBuilder {
        self.graphics = graphics
        return self
    }

    func withAutoBoot(_ autoBoot: Bool?) -> QemuCommandBuilder {
        self.autoBoot = autoBoot
        return self
    }

    func withVgaEnabled(_ vgaEnabled: Bool?) -> QemuCommandBuilder {
        self.vgaEnabled = vgaEnabled
        return self
    }

    func withSound(_ sound: String?) -> QemuCommandBuilder {
        if let soudHw = sound {
            self.sound.append(soudHw)
        }
        return self
    }

    func withRtcEnabled(_ rtcEnabled: Bool) -> QemuCommandBuilder {
        self.rtcEnabled = rtcEnabled
        return self
    }

    func withLogging(_ logging: String?) -> QemuCommandBuilder {
        self.logging = logging
        return self
    }

    func withDrive(file: String, format: String, index: Int, media: String) -> QemuCommandBuilder {
        if media == QemuConstants.MEDIATYPE_USB_CDROM {
            var driveString = "-device usb-storage,drive=drive" + String(index) + ",removable=true,bootindex=" + String(index) + ",bus=usb-bus.0"
            driveString.append(" -drive \"if=none,format=raw,media=cdrom,id=drive" + String(index) + ",file.filename=" + file + ",file.locking=off,readonly=on\"")
            drives.append(driveString)
        } else if media == QemuConstants.MEDIATYPE_USB {
            var driveString = "-device usb-storage,drive=drive" + String(index) + ",removable=false"
            driveString.append(" -drive \"if=none,media=disk,id=drive" + String(index) + ",file=" + file + ",cache=writethrough\"")
            drives.append(driveString)
        } else if media == QemuConstants.MEDIATYPE_NVME {
            var driveString = "-drive file=" + Utils.escape(file)
            driveString.append(",if=none,id=nvme_" + String(index) + ",index=" + String(index) + ",cache=writethrough")
            driveString.append(" -device nvme,drive=nvme_" + String(index) + ",serial=MACMULATOR_NVME_" + String(index))
            drives.append(driveString)
        } else if media == QemuConstants.MEDIATYPE_NVRAM {
            var driveString = "-drive file=" + Utils.escape(file)
            if format != QemuConstants.FORMAT_UNKNOWN {
                driveString.append(",format=" + format)
            }
            driveString.append(",if=pflash,index=1")
            drives.append(driveString)
        } else {
            var driveString = "-drive file=" + Utils.escape(file)
            if format != QemuConstants.FORMAT_UNKNOWN {
                driveString.append(",format=" + format)
            }
            driveString.append(",index=" + String(index) + ",media=" + media)
            drives.append(driveString)
        }
        return self
    }

    func withEfi(file: String) -> QemuCommandBuilder {
        efi = Utils.escape(file)
        return self
    }

    func withEfiSecure(file: String) -> QemuCommandBuilder {
        efiSecure = Utils.escape(file)
        return self
    }

    func withEfiVars(file: String, global: Bool) -> QemuCommandBuilder {
        efiVars = Utils.escape(file)
        globalClause = global ? " -global driver=cfi.pflash01,property=secure,value=on" : ""
        return self
    }

    func withPortMappings(_ portMappings: [PortMapping]?) -> QemuCommandBuilder {
        if let mappings = portMappings {
            self.portMappings = mappings
        }
        return self
    }

    func withNetwork(name: String, device: String, macAddress: String?) -> QemuCommandBuilder {
        network = "-netdev user,id=" + name

        for mapping in portMappings {
            network = network! + ",hostfwd=tcp::" + String(mapping.hostPort) + "-:" + String(mapping.vmPort)
        }

        if let macAddress {
            network = network! + " -device " + device + ",netdev=" + name + ",mac=" + macAddress
        } else {
            network = network! + " -device " + device + ",netdev=" + name
        }
        return self
    }

    func withQmpString(_ addQmpString: Bool?) -> QemuCommandBuilder {
        self.addQmpString = addQmpString
        return self
    }

    func withManagementPort(_ managementPort: Int32) -> QemuCommandBuilder {
        self.managementPort = managementPort
        return self
    }

    func withNic(_ nic: String) -> QemuCommandBuilder {
        self.nic = nic
        return self
    }

    func withTpm(_ tpmPath: String?, _ tpmDevice: String?) -> QemuCommandBuilder {
        self.tpmPath = tpmPath
        self.tpmDevice = tpmDevice
        return self
    }

    func build() -> String {
        var cmd = qemuPath + "/" + executable
        if let serial {
            cmd += " -serial " + serial
        }
        if let bios {
            cmd += " -L " + bios
        }
        if let cpus {
            cmd += " -smp cores=" + String(cpus) + ",threads=1,sockets=1,maxcpus=" + String(cpus)
        }
        if let bootArg {
            cmd += " -boot " + bootArg
        }
        if let accel {
            cmd += " -accel " + accel
        }
        if let vga {
            cmd += " -device " + vga
        }
        if let display {
            cmd += " -display " + display + ",show-cursor="
            if let showCursor, showCursor {
                cmd += "on"
            } else {
                cmd += "off"
            }
            if enable3d ?? false {
                cmd += ",gl=on"
            }
        }
        if let cpu {
            cmd += " -cpu " + cpu
        }
        if let usb, usb {
            cmd += " -usb"
        }
        if let nic {
            cmd += " -nic user,model=" + nic
        }
        for device in device {
            cmd += " -device " + device
        }
        if let machine {
            cmd += " -M " + machine
        }
        if let memory {
            cmd += " -m " + String(memory)
        }
        if let graphics {
            cmd += " -g " + graphics
        }
        for sound in sound {
            cmd += " -device " + sound
        }
        if let autoBoot {
            cmd += " -prom-env 'auto-boot?=" + String(autoBoot) + "'"
        }
        if let vgaEnabled {
            cmd += " -prom-env 'vga-ndrv?=" + String(vgaEnabled) + "'"
        }
        if let efi {
            cmd += " -drive if=pflash,format=raw,unit=0,file.filename=" + efi + ",file.locking=off"
        }
        if let efiSecure {
            cmd += " -drive if=pflash,format=raw,unit=0,file.filename=" + efiSecure + ",file.locking=off"
        }
        if let efiVars {
            cmd += " -drive if=pflash,unit=1,file=" + efiVars + globalClause!
        }
        for drive in drives {
            cmd += " " + drive
        }
        if let network {
            cmd += " " + network
        }
        if addQmpString == true, let managementPort {
            cmd += " -qmp tcp:127.0.0.1:" + String(managementPort) + ",server,nowait"
        }
        if rtcEnabled {
            cmd += " -rtc base=localtime,clock=host"
        }
        if let tpmPath {
            let device = tpmDevice != nil ? tpmDevice! : QemuConstants.TPM_TIS_DEVICE
            cmd += " -chardev socket,id=chrtpm,path=" + Utils.escape(tpmPath) + "/tpm/socket -tpmdev emulator,id=tpm0,chardev=chrtpm -device " + device + ",tpmdev=tpm0"
        }
        if let logging {
            cmd += " -d " + logging
        }

        return cmd
    }
}
