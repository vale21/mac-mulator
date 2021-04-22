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
    var targetFormat: String?;
    var size: Int32?;
    var name: String?;
    var targetName: String?;
    var shrinkArg: Bool?;
    var shortSize: Int32?;
    
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
    
    func withTargetFormat(_ targetFormat: String) -> QemuImgCommandBuilder {
        self.targetFormat = targetFormat;
        return self;
    }
    
    func withSize(_ size: Int32) -> QemuImgCommandBuilder {
        self.size = size;
        return self;
    }
    
    func withName(_ name: String) -> QemuImgCommandBuilder {
        self.name = Utils.escape(name);
        return self;
    }
    
    func withTargetName(_ targetName: String) -> QemuImgCommandBuilder {
        self.targetName = targetName;
        return self;
    }
    
    func withShrinkArg(_ shrinkArg: Bool) -> QemuImgCommandBuilder {
        self.shrinkArg = shrinkArg;
        return self;
    }
    
    func withShortSize(_ shortSize: Int32) -> QemuImgCommandBuilder {
        self.shortSize = shortSize;
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
        if let targetFormat = self.targetFormat {
            cmd += " -O " + targetFormat;
        }
        if let size = self.size {
            cmd += " -o size=" + String(size) + "G";
        }
        if let name = self.name {
            cmd += " " + name;
        }
        if let targetName = self.targetName {
            cmd += " " + targetName;
        }
        if let shrinkArg = self.shrinkArg {
            cmd += shrinkArg ? " --shrink" : "";
        }
        if let shortSize = self.shortSize {
            cmd += " " + String(shortSize) + "G";
        }
        
        return cmd;
    }
}
