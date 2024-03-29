//
//  DriveInfoViewController.swift
//  MacMulator
//
//  Created by Vale on 25/02/21.
//

import Cocoa

class DriveInfoViewController: NSViewController {
    
    @IBOutlet weak var driveName: NSTextField!
    @IBOutlet weak var driveSize: NSTextField!
    @IBOutlet weak var driveFormat: NSTextField!
    @IBOutlet weak var drivePath: NSTextField!
    @IBOutlet var infoView: NSTextView!
    
    var virtualDrive: VirtualDrive?

    func setVirtualDrive(_ virtualDrive: VirtualDrive) {
        self.virtualDrive = virtualDrive;
    }
    
    override func viewWillAppear() {
        if let virtualDrive = self.virtualDrive {
            driveName.stringValue = virtualDrive.name;
            driveSize.stringValue = Utils.formatDisk(virtualDrive.size);
            driveFormat.stringValue = virtualDrive.format + " " + QemuUtils.getDriveFormatDescription(virtualDrive.format);
            drivePath.stringValue = Utils.unescape(virtualDrive.path);
            QemuUtils.getDiskImageInfo(virtualDrive, NSHomeDirectory(), uponCompletion: {
                terminationCcode, info in
                DispatchQueue.main.async {
                    self.infoView.string = info;
                }
            });
        }
    }
}
