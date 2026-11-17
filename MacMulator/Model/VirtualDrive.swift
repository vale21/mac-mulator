//
//  VirtualDrive.swift
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
    var blank: Int? = 1 // TODO: Review why on earth Bool? does not work and we have to do this crap with Int?
    var vzDeviceUUID: String?
    var backingPath: String? // path of the template drive this drive is layered on top of (linked clones only)

    // A copy of the drive settings is kept in an extended attribute of its image, so that the image carries them when it is
    // imported in another VM. info.plist stays the reference: extended attributes are lost by some copies and by conversions.
    private static let metadataAttribute = "it.valedev.MacMulator.drive"

    func setBlank(blank: Bool) {
        self.blank = blank ? 1 : 0
    }

    var isLinked: Bool {
        backingPath != nil
    }

    init(path: String, name: String, format: String, mediaType: String, size: Int32) {
        self.path = path
        self.name = name
        self.format = format
        self.mediaType = mediaType
        self.size = size
    }

    func isBlank() -> Bool {
        blank != nil && blank == 1
    }

    static func readMetadata(fromImageAt imagePath: String) -> VirtualDrive? {
        let size = getxattr(imagePath, metadataAttribute, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { getxattr(imagePath, metadataAttribute, $0.baseAddress, size, 0, 0) }
        guard read == size else { return nil }
        return try? PropertyListDecoder().decode(VirtualDrive.self, from: data)
    }

    func writeMetadataToImage() {
        guard let data = try? PropertyListEncoder().encode(self) else { return }
        _ = data.withUnsafeBytes { setxattr(path, VirtualDrive.metadataAttribute, $0.baseAddress, data.count, 0, 0) }
    }

    func clone() -> VirtualDrive {
        let drive = VirtualDrive(path: path, name: name, format: format, mediaType: mediaType, size: size)
        drive.isBootDrive = isBootDrive
        drive.blank = blank
        drive.backingPath = backingPath

        return drive
    }

    static func == (lhs: VirtualDrive, rhs: VirtualDrive) -> Bool {
        lhs.path == rhs.path &&
            lhs.name == rhs.name &&
            lhs.format == rhs.format &&
            lhs.mediaType == rhs.mediaType &&
            lhs.size == rhs.size &&
            lhs.isBootDrive == rhs.isBootDrive &&
            lhs.blank == rhs.blank &&
            lhs.vzDeviceUUID == rhs.vzDeviceUUID &&
            lhs.backingPath == rhs.backingPath
    }
}
