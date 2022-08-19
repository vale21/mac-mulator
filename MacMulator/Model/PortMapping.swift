//
//  PortMapping.swift
//  MacMulator
//
//  Created by Vale on 03/06/22.
//

import Foundation

class PortMapping: Codable {
    
    var name: String;
    var vmPort: Int32;
    var hostPort: Int32;
    
    init(name: String, vmPort: Int32, hostPort: Int32) {
        self.name = name;
        self.vmPort = vmPort;
        self.hostPort = hostPort;
    }
}
