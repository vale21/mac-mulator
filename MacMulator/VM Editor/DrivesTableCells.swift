//
//  DrivesTableIconCell.swift
//  MacMulator
//
//  Created by Vale on 22/02/21.
//

import Cocoa

class DrivesTableIconCell: NSTableCellView {
    @IBOutlet weak var icon: NSImageView!
}

class DrivesTableDriveTypeCell: NSTableCellView {
    @IBOutlet weak var label: NSTextField!
}

class DrivesTableDriveSizeCell: NSTableCellView {
    @IBOutlet weak var label: NSTextField!
}

class DrivesTableDrivePathCell: NSTableCellView {
    @IBOutlet weak var label: NSTextField!
}
