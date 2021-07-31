//
//  QemuCommandBuilder.swift
//  MacMulator
//
//  Created by Vale on 05/02/21.
//

import Foundation

class QemuCommandBuilder {
        
    var qemuPath: String;
    var executable: String;
    var bios: String?;
    var cpus: Int?;
    var accel: String?;
    var vga: String?;
    var cpu: String?;
    var usb: String?;
    var bootArg: String?;
    var machine: String?;
    var memory: Int32?
    var graphics: String?;
    var autoBoot: Bool?;
    var vgaEnabled: Bool?;
    var soundHw: String?
    var drives: [String] = [];
    var network: String?;
    var managementPort: Int32?;
    
    init(qemuPath: String, architecture: String) {
        self.qemuPath = qemuPath;
        self.executable = architecture;
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
    
    func withCpu(_ cpu: String?) -> QemuCommandBuilder {
        self.cpu = cpu;
        return self;
    }
    
    func withUsb(_ usb: String?) -> QemuCommandBuilder {
        self.usb = usb;
        return self;
    }
    
    func withBootArg(_ bootArg: String?) -> QemuCommandBuilder {
        self.bootArg = bootArg;
        return self;
    }
    
    func withMachine(_ machine: String?) -> QemuCommandBuilder {
        self.machine = machine;
        return self;
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
    
    func withSoundHw(_ soundHw: String?) -> QemuCommandBuilder {
        self.soundHw = soundHw;
        return self;
    }
    
    func withDrive(file: String, format: String, index: Int, media:String)-> QemuCommandBuilder {
        self.drives.append("file=" + Utils.escape(file) + ",format=" + format + ",index=" + String(index) + ",media=" + media);
        return self;
    }
    
    func withNetwork(name: String, device: String) -> QemuCommandBuilder{
        self.network = "-netdev user,id=" + name + " -device " + device + ",netdev=" + name;
        return self;
    }
    
    func withManagementPort(_ managementPort: Int32) -> QemuCommandBuilder {
        self.managementPort = managementPort;
        return self;
    }
    
    func build() -> String {
        var cmd = self.qemuPath + "/" + self.executable;
        if let bios = self.bios {
            cmd += " -L " + bios;
        }
        if let cpus = self.cpus {
            cmd += " -smp cores=" + String(cpus) + ",threads=1,sockets=1,maxcpus=" + String(cpus);
        }
        if let bootArg = self.bootArg {
            cmd += " -boot " + bootArg;
        }
        if let accel = self.accel {
            cmd += " -accel " + accel;
        }
        if let vga = self.vga {
            cmd += " -vga " + vga;
        }
        if let cpu = self.cpu {
            cmd += " -cpu " + cpu;
        }
        if let usb = self.usb {
            cmd += " -usb -device " + usb;
        }
        if let machine = self.machine {
            cmd += " -M " + machine;
        }
        if let memory = self.memory {
            cmd += " -m " + String(memory);
        }
        if let graphics = self.graphics {
            cmd += " -g " + graphics;
        }
        if let soundHw = self.soundHw {
            cmd += " -soundhw " + soundHw;
        }
        if let autoBoot = self.autoBoot {
            cmd += " -prom-env 'auto-boot?=" + String(autoBoot) + "'";
        }
        if let vgaEnabled = self.vgaEnabled {
            cmd += " -prom-env 'vga-ndrv?=" + String(vgaEnabled) + "'";
        }
        for drive in self.drives {
            cmd += " -drive " + drive;
        }
        if let network = self.network {
            cmd += " " + network;
        }
        if let managementPort = self.managementPort {
            cmd += " -qmp tcp:127.0.0.1:" + String(managementPort) + ",server,nowait";
        }
        
        return cmd;
    }
}
