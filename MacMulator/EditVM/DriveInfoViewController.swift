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
        // qemu-img describes every format except ASIF, which only Apple's tools understand.
        let useQemuImg = virtualDrive?.format != QemuConstants.FORMAT_ASIF
        infoViewLabel.stringValue = useQemuImg ? NSLocalizedString("DriveInfoViewController.infoViewLabelQemu", comment: "") : NSLocalizedString("DriveInfoViewController.infoViewLabelApple", comment: "")
        infoView.string = NSLocalizedString("DriveInfoViewController.infoViewDefault", comment: "")

        if let virtualDrive {
            driveName.stringValue = virtualDrive.name
            driveSize.stringValue = Utils.formatDisk(virtualDrive.size)
            driveFormat.stringValue = virtualDrive.format + " " + QemuUtils.getDriveFormatDescription(virtualDrive.format)
            drivePath.stringValue = Utils.unescape(virtualDrive.path)
            if useQemuImg {
                QemuUtils.getDiskImageInfo(virtualDrive, NSHomeDirectory(), uponCompletion: {
                    code, info in
                    // Apple VMs in the Enthusiast flavor may run without a Qemu installation.
                    if code != 0, self.isVirtualizaionFrameworkInUse {
                        self.showVirtualizationFrameworkInfo(virtualDrive)
                        return
                    }
                    DispatchQueue.main.async {
                        self.infoViewLabel.stringValue = NSLocalizedString("DriveInfoViewController.infoViewLabelQemu", comment: "")
                        self.infoView.string = info
                    }
                })
            } else {
                showVirtualizationFrameworkInfo(virtualDrive)
            }
        }
    }

    private func showVirtualizationFrameworkInfo(_ virtualDrive: VirtualDrive) {
        VirtualizationFrameworkUtils.getDiskImageInfo(virtualDrive, NSHomeDirectory(), uponCompletion: {
            _, info in
            DispatchQueue.main.async {
                self.infoViewLabel.stringValue = NSLocalizedString("DriveInfoViewController.infoViewLabelApple", comment: "")
                self.infoView.string = info
            }
        })
    }
}
