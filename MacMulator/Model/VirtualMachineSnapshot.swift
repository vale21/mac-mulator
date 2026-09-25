//
//  VirtualMachineSnapshot.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Foundation

class VirtualMachineSnapshot: Codable, Equatable {
    var timestamp: Int64
    var name: String
    var description: String
    var driveSnapshotPaths: [String]
    var memorySnapshotPath: String?
    var screenshotPath: String
    var running: Bool

    init(timestamp: Int64, name: String, description: String, driveSnapshotPaths: [String], memorySnapshotPath: String?, screenshotPath: String, running: Bool) {
        self.timestamp = timestamp
        self.name = name
        self.description = description
        self.driveSnapshotPaths = driveSnapshotPaths
        self.memorySnapshotPath = memorySnapshotPath
        self.screenshotPath = screenshotPath
        self.running = running
    }

    static func == (lhs: VirtualMachineSnapshot, rhs: VirtualMachineSnapshot) -> Bool {
        lhs.timestamp == rhs.timestamp
            && lhs.driveSnapshotPaths == rhs.driveSnapshotPaths
            && lhs.memorySnapshotPath == rhs.memorySnapshotPath
            && lhs.screenshotPath == rhs.screenshotPath
            && lhs.running == rhs.running
    }
}
