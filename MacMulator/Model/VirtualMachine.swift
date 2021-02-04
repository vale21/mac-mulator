//
//  VirtualMachine.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Foundation

class VirtualMachine: Codable, Hashable {
    
    var path: String;
    var displayName: String;
    var memory: Int32;
    var displayResolution: String;
    var bootArg: String;
    var drives: [VirtualDrive];
    var isNew: Bool = true;
    
    init(path: String,  displayName: String, memory: Int32, displayResolution: String, bootArg: String) {
        self.path = path;
        self.displayName = displayName;
        self.memory = memory;
        self.displayResolution = displayResolution;
        self.bootArg = bootArg;
        self.drives = [];
    }
    
    func addVirtualDrive(_ drive: VirtualDrive){
        drives.append(drive);
    }
    
    static func readFromPlist(_ plistFilePath: String) -> VirtualMachine? {
        let fileManager = FileManager.default;
        do {
            let xml = fileManager.contents(atPath: plistFilePath);
            return try PropertyListDecoder().decode(VirtualMachine.self, from: xml!);
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
        try data.write(to: URL(fileURLWithPath: self.path + "/Info.plist"));
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
    
    enum CodingKeys: String, CodingKey {
        case path
        case displayName
        case memory
        case displayResolution
        case bootArg
        case drives
    }
}
