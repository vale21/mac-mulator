//
//  VirtualMachine.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Foundation

class VirtualMachine: Codable, Hashable {
    
    var os: String;
    var architecture: String;
    var path: String = "";
    var displayName: String;
    var description: String?;
    var cpus: Int;
    var memory: Int32;
    var displayResolution: String;
    var qemuBootLoader: Bool;
    var drives: [VirtualDrive];
    var qemuPath: String?;
    var qemuCommand: String?;
    
    init(os: String, architecture: String, path: String,  displayName: String, description: String?, memory: Int32, displayResolution: String, qemuBootloader: Bool) {
        self.os = os;
        self.architecture = architecture;
        self.path = path;
        self.displayName = displayName;
        self.description = description;
        self.memory = memory;
        self.cpus = 1;
        self.displayResolution = displayResolution;
        self.qemuBootLoader = qemuBootloader;
        self.drives = [];
    }
    
    func addVirtualDrive(_ drive: VirtualDrive){
        drives.append(drive);
    }
    
    static func readFromPlist(_ plistFilePath: String, _ plistFileName: String) -> VirtualMachine? {
        let fileManager = FileManager.default;
        do {
            let xml = fileManager.contents(atPath: plistFilePath + "/" + plistFileName);
            let vm = try PropertyListDecoder().decode(VirtualMachine.self, from: xml!);
            vm.path = plistFilePath;
            return vm;
        } catch {
            print("ERROR while reading Info.plist: " + error.localizedDescription);
            return nil;
        }
    }
    
    func writeToPlist(_ plistFilePath: String) {
        do {
            let data = try PropertyListEncoder().encode(self);
            try data.write(to: URL(fileURLWithPath: plistFilePath));
        } catch {
            print("ERROR while writing Info.plist: " + error.localizedDescription);
        }
    }
    
    func writeToPlist() {
        do {
            let data = try PropertyListEncoder().encode(self);
            try data.write(to: URL(fileURLWithPath: self.path + "/" + MacMulatorConstants.INFO_PLIST));
        } catch {
            print("ERROR while writing Info.plist: " + error.localizedDescription);
        }
    }
    
    static func == (lhs: VirtualMachine, rhs: VirtualMachine) -> Bool {
        return lhs.displayName == rhs.displayName;
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName);
    }
}
