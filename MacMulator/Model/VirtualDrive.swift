//
//  Virtualdrive.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Foundation

class VirtualDrive: Codable, Equatable {

    var path: String // this value is serialized, but is ignored for media type different from CDROM
    var name: String
    var format: String
    var mediaType: String
    var size: Int32
    var isBootDrive: Bool = false
    var blank: Int? = 1 // TODO Review why on earth Bool? does not work and we have to do this crap with Int?

    init(path: String, name: String, format: String, mediaType: String, size: Int32) {
        self.path = path
        self.name = name
        self.format = format
        self.mediaType = mediaType
        self.size = size
    }
    
    func isBlank() -> Bool {
        return blank != nil && blank == 1
    }
    
    func setBlank(blank: Bool) {
        self.blank = blank ? 1 : 0
    }
    
    func clone() -> VirtualDrive {
        let drive = VirtualDrive(path: self.path, name: self.name, format: self.format, mediaType: self.mediaType, size: self.size);
        drive.isBootDrive = self.isBootDrive
        drive.blank = self.blank
        
        return drive;
    }
    
    static func == (lhs: VirtualDrive, rhs: VirtualDrive) -> Bool {
        return lhs.path == rhs.path &&
        lhs.name == rhs.name &&
        lhs.format == rhs.format &&
        lhs.mediaType == rhs.mediaType &&
        lhs.size == rhs.size &&
        lhs.isBootDrive == rhs.isBootDrive &&
        lhs.blank == rhs.blank
    }
}
