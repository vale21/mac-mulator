//
//  Virtualdrive.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Foundation

class VirtualDrive {
    
    var name: String;
    var format: String;
    var mediaType: String;

    init(name: String, format: String, mediaType: String) {
        self.name = name;
        self.format = format;
        self.mediaType = mediaType;
    }
}
