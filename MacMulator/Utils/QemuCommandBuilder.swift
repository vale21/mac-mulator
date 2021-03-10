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
    var bootArg: String?;
    var machine: String?;
    var memory: Int32?
    var graphics: String?;
    var autoBoot: Bool?;
    var vgaEnabled: Bool?;
    var drives: [String] = [];
    var network: String?;
    var managementPort: Int32?;
    
    init(qemuPath: String, architecture: String) {
        self.qemuPath = qemuPath;
        self.executable = architecture;
    }
    
    func withBios(_ bios: String) -> QemuCommandBuilder {
        self.bios = bios;
        return self;
    }
    
    func withCpus(_ cpus: Int) -> QemuCommandBuilder {
        self.cpus = cpus;
        return self;
    }
    
    func withBootArg(_ bootArg: String) -> QemuCommandBuilder {
        self.bootArg = bootArg;
        return self;
    }
    
    func withMachine(_ machine: String) -> QemuCommandBuilder {
        self.machine = machine;
        return self;
    }
    
    func withMemory(_ memory: Int32) -> QemuCommandBuilder {
        self.memory = memory;
        return self;
    }
    
    func withGraphics(_ graphics: String) -> QemuCommandBuilder {
        self.graphics = graphics;
        return self;
    }
    
    func withAutoBoot(_ autoBoot: Bool) -> QemuCommandBuilder {
        self.autoBoot = autoBoot;
        return self;
    }
    
    func withVgaEnabled(_ vgaEnabled: Bool) -> QemuCommandBuilder {
        self.vgaEnabled = vgaEnabled;
        return self;
    }
    
    func withDrive(file: String, format: String, index: Int, media:String)-> QemuCommandBuilder {
        self.drives.append("file=" + file + ",format=" + format + ",index=" + String(index) + ",media=" + media);
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
            cmd += " -smp " + String(cpus);
        }
        if let bootArg = self.bootArg {
            cmd += " -boot " + bootArg;
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
            cmd += " -qmp tcp:localhost:" + String(managementPort) + ",server,nowait";
        }
        
        return cmd;
    }
}
