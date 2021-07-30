//
//  QemuMonitor.swift
//  MacMulator
//
//  Created by Vale on 08/06/21.
//

import Foundation
import SocketSwift

class QemuMonitor {
    
    var connected: Bool;
    var client: Socket?;
 
    init(_ port: Int32) {
        client = nil;
        connected = false;
        
        do{
            self.client = try Socket(.inet, type: .stream, protocol: .tcp)
            if let client = self.client {
                try client.connect(port: UInt16(port));

                var buffer = [UInt8](repeating: 0, count: 1024)
                try client.read(&buffer, size: 1024);
 
                let command = "{ \"execute\": \"qmp_capabilities\" }\r\n"
                try client.write(Array(command.data(using: .utf8)!));
                try client.read(&buffer, size: 1024);

                connected = true;
            }
        } catch {
            print("Cannot establish TCP connection with localhost:" + String(port) + ": " + error.localizedDescription);
        }
    }
    
    func close() {
        if connected {
            client?.close();
        }
        connected = false;
    }
    
    func takeScreenshot(path: String) {
        if connected {
            let command = "{ \"execute\": \"screendump\", \"arguments\": { \"filename\": \"" + path +  "\" } }\n";
            if let client = self.client {
                do {
                    try client.write(Array(command.data(using: .utf8)!));
                    
                    var buffer = [UInt8](repeating: 0, count: 1024) // allocate buffer
                    try client.read(&buffer, size: 1024);
                } catch {
                    print("Cannot take screenshot from Qemu: " + error.localizedDescription);
                }
            }
        }
    }
}
