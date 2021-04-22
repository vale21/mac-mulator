//
//  Virtualdrive.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Foundation

class VirtualDrive: Codable {
    
    var path: String; // this value is serialized, but is ignored for media type different from CDROM
    var name: String;
    var format: String;
    var mediaType: String;
    var size: Int32;
    var isBootDrive: Bool;

    init(path: String, name: String, format: String, mediaType: String, size: Int32) {
        self.path = path;
        self.name = name;
        self.format = format;
        self.mediaType = mediaType;
        self.size = size;
        self.isBootDrive = false;
    }
    
    func setBootDrive(_ bootDrive: Bool) {
        self.isBootDrive = bootDrive;
    }
    
    func clone() -> VirtualDrive {
        let drive = VirtualDrive(path: self.path, name: self.name, format: self.format, mediaType: self.mediaType, size: self.size);
        drive.setBootDrive(self.isBootDrive);
        
        return drive;
    }
}
