//
//  VirtualMachine.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Foundation

class VirtualMachine: Codable, Hashable {
    
    var os: String
    var subtype: String
    var architecture: String
    var path: String = ""
    var displayName: String
    var description: String
    var cpus: Int
    var memory: Int32
    var displayResolution: String
    var displayOrigin: String?
    var qemuBootLoader: Bool
    var networkDevice: String?
    var drives: [VirtualDrive]
    var qemuPath: String?
    var qemuCommand: String?
    var hvf: Bool?
    var portMappings: [PortMapping]?
    var macAddress: String?
    var type: String?
    var pauseSupported: Bool? = false
    
    private enum CodingKeys: String, CodingKey {
        case os, subtype, architecture, displayName, description, cpus, memory, displayResolution, displayOrigin, qemuBootLoader, networkDevice, drives, qemuPath, qemuCommand, hvf, portMappings, macAddress, type;
    }
    
    init(os: String, subtype: String, architecture: String, path: String, displayName: String, description: String, memory: Int32, cpus: Int, displayResolution: String, displayOrigin: String, networkDevice: String, qemuBootloader: Bool, hvf: Bool, macAddress: String?, type: String) {
        self.os = os
        self.subtype = subtype
        self.architecture = architecture
        self.path = path
        self.displayName = displayName
        self.description = description
        self.memory = memory
        self.cpus = cpus
        self.displayResolution = displayResolution
        self.displayOrigin = displayOrigin
        self.networkDevice = networkDevice
        self.qemuBootLoader = qemuBootloader
        self.hvf = hvf
        self.drives = []
        self.portMappings = [PortMapping(name: "SSH port mapping", vmPort: 22, hostPort: Utils.random(digits: 2, suffix: 22))]
        self.macAddress = macAddress
        self.type = type
    }
    
    func addVirtualDrive(_ drive: VirtualDrive){
        drives.append(drive);
    }
    
    func addPortMapping(_ portMapping: PortMapping){
        portMappings?.append(portMapping);
    }
    
    static func readFromPlist(_ plistFilePath: String, _ plistFileName: String) -> VirtualMachine? {
        let fileManager = FileManager.default;
        do {
            let xml = fileManager.contents(atPath: plistFilePath + "/" + plistFileName);
            let vm = try PropertyListDecoder().decode(VirtualMachine.self, from: xml!);
            setupPaths(vm, plistFilePath);
            if vm.portMappings == nil {
                vm.portMappings = [PortMapping(name: "SSH port mapping", vmPort: 22, hostPort: Utils.random(digits: 2, suffix: 22))]
            }
            return vm;
        } catch {
            print("ERROR while reading Info.plist: " + error.localizedDescription);
            return nil;
        }
    }
    
    static func setupPaths(_ vm: VirtualMachine, _ plistFilePath: String) {
        vm.path = plistFilePath;
        for drive in vm.drives {
            if drive.mediaType != QemuConstants.MEDIATYPE_CDROM {
                if drive.mediaType == QemuConstants.MEDIATYPE_DISK {
                    drive.path = plistFilePath + "/" + drive.name + "." + MacMulatorConstants.DISK_EXTENSION;
                } else if drive.mediaType == QemuConstants.MEDIATYPE_EFI {
                    drive.path = plistFilePath + "/" + drive.name + "." + MacMulatorConstants.EFI_EXTENSION;
                } else if drive.mediaType == QemuConstants.MEDIATYPE_OPENCORE {
                    drive.path = plistFilePath + "/" + drive.name + "." + MacMulatorConstants.IMG_EXTENSION;
                }
            }
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
