//
//  VirtualMachine.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Foundation

class VirtualMachine {
    
    var displayName: String;
    var memory: Int32;
    var displayResolution: String;
    var bootArg: String;
    var drives: [VirtualDrive];
    
    init(displayName: String, memory: Int32, displayResolution: String, bootArg: String) {
        self.displayName = displayName;
        self.memory = memory;
        self.displayResolution = displayResolution;
        self.bootArg = bootArg;
        self.drives = [];
    }
    
    func addVirtualDrive(_ drive: VirtualDrive){
        drives.append(drive);
    }
}
