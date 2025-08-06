//
//  DriveInfoViewController.swift
//  MacMulator
//
//  Created by Vale on 25/02/21.
//

import Cocoa

class DriveInfoViewController: NSViewController {
    @IBOutlet var driveNameLabel: NSTextField!
    @IBOutlet var driveName: NSTextField!
    @IBOutlet var driveSizeLabel: NSTextField!
    @IBOutlet var driveSize: NSTextField!
    @IBOutlet var driveFormatLabel: NSTextField!
    @IBOutlet var driveFormat: NSTextField!
    @IBOutlet var drivePathLabel: NSTextField!
    @IBOutlet var drivePath: NSTextField!
    @IBOutlet var infoViewLabel: NSTextField!
    @IBOutlet var infoView: NSTextView!

    var virtualDrive: VirtualDrive?
    var isVirtualizaionFrameworkInUse: Bool = false

    func setVirtualDrive(_ virtualDrive: VirtualDrive) {
        self.virtualDrive = virtualDrive
    }

    override func viewWillAppear() {
        driveNameLabel.stringValue = NSLocalizedString("DriveInfoViewController.driveNameLabel", comment: "")
        driveSizeLabel.stringValue = NSLocalizedString("DriveInfoViewController.driveSizeLabel", comment: "")
        driveFormatLabel.stringValue = NSLocalizedString("DriveInfoViewController.driveFormatLabel", comment: "")
        drivePathLabel.stringValue = NSLocalizedString("DriveInfoViewController.drivePathLabel", comment: "")
        infoViewLabel.stringValue = virtualDrive?.format == QemuConstants.FORMAT_QCOW2 ? NSLocalizedString("DriveInfoViewController.infoViewLabelQemu", comment: "") : NSLocalizedString("DriveInfoViewController.infoViewLabelApple", comment: "")
        infoView.string = NSLocalizedString("DriveInfoViewController.infoViewDefault", comment: "")

        if let virtualDrive {
            driveName.stringValue = virtualDrive.name
            driveSize.stringValue = Utils.formatDisk(virtualDrive.size)
            driveFormat.stringValue = virtualDrive.format + " " + QemuUtils.getDriveFormatDescription(virtualDrive.format)
            drivePath.stringValue = Utils.unescape(virtualDrive.path)
            if virtualDrive.format == QemuConstants.FORMAT_QCOW2 {
                QemuUtils.getDiskImageInfo(virtualDrive, NSHomeDirectory(), uponCompletion: {
                    _, info in
                    DispatchQueue.main.async {
                        self.infoView.string = info
                    }
                })
            } else {
                VirtualizationFrameworkUtils.getDiskImageInfo(virtualDrive, NSHomeDirectory(), uponCompletion: {
                    _, info in
                    DispatchQueue.main.async {
                        self.infoView.string = info
                    }
                })
            }
        }
    }
}
