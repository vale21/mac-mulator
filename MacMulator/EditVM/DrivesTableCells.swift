//
//  DrivesTableCells.swift
//  MacMulator
//
//  Created by Vale on 22/02/21.
//

import Cocoa

class DrivesTableIconCell: NSTableCellView {
    @IBOutlet var icon: NSImageView!
}

class DrivesTableDriveNameCell: NSTableCellView {
    @IBOutlet var label: NSTextField!
}

class DrivesTableDriveTypeCell: NSTableCellView {
    @IBOutlet var label: NSTextField!
}

class DrivesTableDriveSizeCell: NSTableCellView {
    @IBOutlet var label: NSTextField!
}

class DrivesTableDrivePathCell: NSTableCellView {
    @IBOutlet var label: NSTextField!
}

class DrivesTableButtonsCell: NSTableCellView {
    @IBOutlet var infoButton: NSButton!
    @IBOutlet var editButton: NSButton!
    @IBOutlet var deleteButton: NSButton!
}
