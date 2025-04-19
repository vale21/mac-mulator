//
//  DriveInfoViewController.swift
//  MacMulator
//
//  Created by Vale on 25/02/21.
//

import Cocoa

class DriveInfoViewController: NSViewController {
    @IBOutlet var driveName: NSTextField!
    @IBOutlet var driveSize: NSTextField!
    @IBOutlet var driveFormat: NSTextField!
    @IBOutlet var drivePath: NSTextField!
    @IBOutlet var infoView: NSTextView!

    var virtualDrive: VirtualDrive?

    func setVirtualDrive(_ virtualDrive: VirtualDrive) {
        self.virtualDrive = virtualDrive
    }

    override func viewWillAppear() {
        if let virtualDrive = virtualDrive {
            driveName.stringValue = virtualDrive.name
            driveSize.stringValue = Utils.formatDisk(virtualDrive.size)
            driveFormat.stringValue = virtualDrive.format + " " + QemuUtils.getDriveFormatDescription(virtualDrive.format)
            drivePath.stringValue = Utils.unescape(virtualDrive.path)
            QemuUtils.getDiskImageInfo(virtualDrive, NSHomeDirectory(), uponCompletion: {
                _, info in
                DispatchQueue.main.async {
                    self.infoView.string = info
                }
            })
        }
    }
}
