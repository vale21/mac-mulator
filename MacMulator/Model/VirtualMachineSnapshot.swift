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
    var driveSnapshotPath: String
    var memorySnapshotPath: String?
    var screenshotPath: String

    init(timestamp: Int64, name: String, description: String, driveSnapshotPath: String, memorySnapshotPath: String?, screenshotPath: String) {
        self.timestamp = timestamp
        self.name = name
        self.description = description
        self.driveSnapshotPath = driveSnapshotPath
        self.memorySnapshotPath = memorySnapshotPath
        self.screenshotPath = screenshotPath
    }

    static func == (lhs: VirtualMachineSnapshot, rhs: VirtualMachineSnapshot) -> Bool {
        lhs.timestamp == rhs.timestamp
            && lhs.driveSnapshotPath == rhs.driveSnapshotPath
            && lhs.memorySnapshotPath == rhs.memorySnapshotPath
            && lhs.screenshotPath == rhs.screenshotPath
    }
}
