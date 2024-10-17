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
    var drives: [String] = []
    var network: String?
    var portMappings: [PortMapping] = []
    var managementPort: Int32?
    var nic: String?
    var tpmPath: String?
    var rtcEnabled: Bool = true
    var logging: String?
    
    init(qemuPath: String, architecture: String) {
        self.qemuPath = qemuPath;
        self.executable = architecture;
    }
    
    func withShowCursor(_ showCursor: Bool) -> QemuCommandBuilder {
        self.showCursor = showCursor;
        return self;
    }
    
    func withSerial(_ serial: String?) -> QemuCommandBuilder {
        self.serial = serial;
        return self;
    }
    
    func withBios(_ bios: String?) -> QemuCommandBuilder {
        self.bios = bios;
        return self;
    }
    
    func withCpus(_ cpus: Int?) -> QemuCommandBuilder {
        self.cpus = cpus;
        return self;
    }
        
    func withAccel(_ accel: String?) -> QemuCommandBuilder {
        self.accel = accel;
        return self;
    }
    
    func withVga(_ vga: String?) -> QemuCommandBuilder {
        self.vga = vga;
        return self;
    }
    
    func withDisplay(_ display: String?) -> QemuCommandBuilder {
        self.display = display;
        return self;
    }
    
    func withCpu(_ cpu: String?) -> QemuCommandBuilder {
        self.cpu = cpu;
        return self;
    }
    
    func withUsb(_ usb: Bool) -> QemuCommandBuilder {
        self.usb = usb;
        return self;
    }
    
    func withDevice(_ device: String?) -> QemuCommandBuilder {
        if let newDevice = device {
            self.device.append(newDevice);
        }
        return self;
    }
    
    func withBootArg(_ bootArg: String?) -> QemuCommandBuilder {
        self.bootArg = bootArg;
        return self;
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
        self.memory = memory;
        return self;
    }
    
    func withGraphics(_ graphics: String?) -> QemuCommandBuilder {
        self.graphics = graphics;
        return self;
    }
    
    func withAutoBoot(_ autoBoot: Bool?) -> QemuCommandBuilder {
        self.autoBoot = autoBoot;
        return self;
    }
    
    func withVgaEnabled(_ vgaEnabled: Bool?) -> QemuCommandBuilder {
        self.vgaEnabled = vgaEnabled;
        return self;
    }
    
    func withSound(_ sound: String?) -> QemuCommandBuilder {
        if let soudHw = sound {
            self.sound.append(soudHw);
        }
        return self;
    }
    
    func withRtcEnabled(_ rtcEnabled: Bool) -> QemuCommandBuilder {
        self.rtcEnabled = rtcEnabled;
        return self;
    }
    
    func withLogging(_ logging: String?) -> QemuCommandBuilder {
        self.logging = logging;
        return self;
    }
    
    func withDrive(file: String, format: String, index: Int, media:String)-> QemuCommandBuilder {
        if media == QemuConstants.MEDIATYPE_USB {
            var driveString = "-device usb-storage,drive=drive" + String(index) + ",removable=false";
            driveString.append(" -drive \"if=none,media=disk,id=drive" + String(index) + ",file=" + file + ",cache=writethrough\"");
            self.drives.append(driveString);
        } else if media == QemuConstants.MEDIATYPE_NVME {
            var driveString = "-drive file=" + Utils.escape(file);
            driveString.append(",if=none,id=nvme_" + String(index) + ",index=" + String(index) + ",cache=writethrough");
            driveString.append(" -device nvme,drive=nvme_" + String(index) + ",serial=MACMULATOR_NVME_" + String(index));
            self.drives.append(driveString);
        } else if media == QemuConstants.MEDIATYPE_NVRAM {
            var driveString = "-drive file=" + Utils.escape(file);
            if format != QemuConstants.FORMAT_UNKNOWN {
                driveString.append(",format=" + format);
            }
            driveString.append(",if=pflash,index=1");
            self.drives.append(driveString);
        } else {
            var driveString = "-drive file=" + Utils.escape(file);
            if format != QemuConstants.FORMAT_UNKNOWN {
                driveString.append(",format=" + format);
            }
            driveString.append(",index=" + String(index) + ",media=" + media);
            self.drives.append(driveString);
        }
        return self;
    }
    
    func withEfi(file: String)-> QemuCommandBuilder {
        self.efi = Utils.escape(file);
        return self;
    }
    
    func withEfiSecure(file: String)-> QemuCommandBuilder {
        self.efiSecure = Utils.escape(file);
        return self;
    }
    
    func withEfiVars(file: String)-> QemuCommandBuilder {
        self.efiVars = Utils.escape(file);
        return self;
    }
    
    func withPortMappings(_ portMappings: [PortMapping]?) -> QemuCommandBuilder {
        if let mappings = portMappings {
            self.portMappings = mappings
        }
        return self;
    }
    
    func withNetwork(name: String, device: String, macAddress: String?) -> QemuCommandBuilder{
        self.network = "-netdev user,id=" + name
        
        for mapping in portMappings {
            self.network = self.network! + ",hostfwd=tcp::" + String(mapping.hostPort) + "-:" + String(mapping.vmPort)
        }
        
        if let macAddress = macAddress {
            self.network = self.network! + " -device " + device + ",netdev=" + name + ",mac=" + macAddress
        } else {
            self.network = self.network! + " -device " + device + ",netdev=" + name
        }
        return self;
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
    
    func withTpm(_ tpmPath: String?) -> QemuCommandBuilder {
        self.tpmPath = tpmPath
        return self
    }
    
    func build() -> String {
        var cmd = self.qemuPath + "/" + self.executable;
        if let serial = self.serial {
            cmd += " -serial " + serial
        }
        if let bios = self.bios {
            cmd += " -L " + bios
        }
        if let cpus = self.cpus {
            cmd += " -smp cores=" + String(cpus) + ",threads=1,sockets=1,maxcpus=" + String(cpus)
        }
        if let bootArg = self.bootArg {
            cmd += " -boot " + bootArg
        }
        if let accel = self.accel {
            cmd += " -accel " + accel
        }
        if let vga = self.vga {
            cmd += " -device " + vga
        }
        if let display = self.display {
            cmd += " -display " + display + ",show-cursor=";
            if let showCursor = self.showCursor, showCursor {
                cmd += "on"
            } else {
                cmd += "off"
            }
        }
        if let cpu = self.cpu {
            cmd += " -cpu " + cpu
        }
        if let usb = self.usb, usb {
            cmd += " -usb"
        }
        if let nic = self.nic {
            cmd += " -nic user,model=" + nic
        }
        for device in self.device {
            cmd += " -device " + device
        }
        if let machine = self.machine {
            cmd += " -M " + machine
        }
        if let memory = self.memory {
            cmd += " -m " + String(memory)
        }
        if let graphics = self.graphics {
            cmd += " -g " + graphics
        }
        for sound in self.sound {
            cmd += " -device " + sound
        }
        if let autoBoot = self.autoBoot {
            cmd += " -prom-env 'auto-boot?=" + String(autoBoot) + "'"
        }
        if let vgaEnabled = self.vgaEnabled {
            cmd += " -prom-env 'vga-ndrv?=" + String(vgaEnabled) + "'"
        }
        if let efi = self.efi {
            cmd += " -bios " + efi
        }
        if let efiSecure = self.efiSecure {
            cmd += " -drive if=pflash,format=raw,unit=0,file.filename=" + efiSecure + ",file.locking=off,readonly=on"
        }
        if let efiVars = self.efiVars {
            cmd += " -drive if=pflash,unit=1,file=" + efiVars + " -global driver=cfi.pflash01,property=secure,value=on"
        }
        for drive in self.drives {
            cmd += " " + drive
        }
        if let network = self.network {
            cmd += " " + network
        }
        if self.addQmpString == true, let managementPort = self.managementPort{
            cmd += " -qmp tcp:127.0.0.1:" + String(managementPort) + ",server,nowait"
        }
        if self.rtcEnabled {
            cmd += " -rtc base=localtime,clock=host"
        }
        if let tpmPath = self.tpmPath {
            cmd += " -chardev socket,id=chrtpm,path=" + Utils.escape(tpmPath) + "/tpm/socket -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0"
        }
        if let logging = self.logging {
            cmd += " -d " + logging
        }
        
        return cmd;
    }
}
