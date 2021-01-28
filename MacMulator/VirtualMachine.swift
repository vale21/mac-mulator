//
//  VirtualMachine.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Foundation

class VirtualMachine {
    
    var name: String;
    var displayName: String;
    var memory: Int32;
    var resolution: String;
    var bootArg: String;
    var drives: [VirtualDrive];
    
    init(name: String, displayName: String, memory: Int32, resolution: String, bootArg: String) {
        self.name = name;
        self.displayName = displayName;
        self.memory = memory;
        self.resolution = resolution;
        self.bootArg = bootArg;
        self.drives = [];
    }
    
    func addVirtualDrive(drive: VirtualDrive){
        drives.append(drive);
    }
}
