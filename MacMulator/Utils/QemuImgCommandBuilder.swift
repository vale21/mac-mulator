//
//  QemuImgCommandBuilder.swift
//  MacMulator
//
//  Created by Vale on 05/02/21.
//

import Foundation

class QemuImgCommandBuilder {
    
    var qemuPath: String;
    var executable: String = "qemu-img";
    var command: String?;
    var format: String?;
    var size: Int32?;
    var name: String?;
    var ext: String?;
    
    init(qemuPath: String) {
        self.qemuPath = qemuPath;
    }
    
    func withCommand(_ command: String) -> QemuImgCommandBuilder {
        self.command = command;
        return self;
    }
    
    func withFormat(_ format: String) -> QemuImgCommandBuilder {
        self.format = format;
        return self;
    }
    
    func withSize(_ size: Int32) -> QemuImgCommandBuilder {
        self.size = size;
        return self;
    }
    
    func withName(_ name: String) -> QemuImgCommandBuilder {
        self.name = name;
        return self;
    }
    
    func withExtension(_ ext: String) -> QemuImgCommandBuilder {
        self.ext = ext;
        return self;
    }
    
    func build() -> String {
        var cmd = self.qemuPath + "/" + self.executable;
        if let command = self.command {
            cmd += " " + command;
        }
        if let format = self.format {
            cmd += " -f " + format;
        }
        if let size = self.size {
            cmd += " -o size=" + String(size) + "G";
        }
        if let name = self.name {
            cmd += " " + name;
        }
        if let ext = self.ext {
            cmd += ext;
        }
        
        return cmd;
    }
}
