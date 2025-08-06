//
//  CreateDiskFileViewController.swift
//  MacMulator
//
//  Created by Vale on 23/02/21.
//

import Cocoa

class CreateDiskFileViewController: NSViewController {
    @IBOutlet var diskProgressLabel: NSTextField!
    @IBOutlet var progressBar: NSProgressIndicator!

    var oldVirtualDrive: VirtualDrive?
    var newVirtualDrive: VirtualDrive?
    var parentController: NewDiskViewController?
    var isVirtualizaionFrameworkInUse: Bool = false

    func setOldVirtualDrive(_ virtualDrive: VirtualDrive?) {
        oldVirtualDrive = virtualDrive
    }

    func setNewVirtualDrive(_ virtualDrive: VirtualDrive?) {
        newVirtualDrive = virtualDrive
    }

    func setParentController(_ parentController: NewDiskViewController) {
        self.parentController = parentController
    }

    override func viewDidAppear() {
        progressBar.startAnimation(self)

        if let newVirtualDrive {
            var complete = false

            let dispatchQueue = DispatchQueue(label: "New Disk Thread", qos: DispatchQoS.background)
            DispatchQueue.main.async {
                if self.parentController?.mode == NewDiskViewController.Mode.ADD {
                    self.diskProgressLabel.stringValue = NSLocalizedString("CreateDiskFileViewController.creatingDisk", comment: "")
                    if self.isVirtualizaionFrameworkInUse {
                        if #available(macOS 26.0, *), newVirtualDrive.format == QemuConstants.FORMAT_ASIF {
                            VirtualizationFrameworkUtils.createASIFDiskImage(path: newVirtualDrive.path, virtualDrive: newVirtualDrive, uponCompletion: {
                                _ in
                                complete = true
                            })
                        } else {
                            VirtualizationFrameworkUtils.createRAWDiskImage(path: newVirtualDrive.path, virtualDrive: newVirtualDrive, uponCompletion: {
                                _ in
                                complete = true
                            })
                        }
                    } else {
                        QemuUtils.createDiskImage(path: newVirtualDrive.path, virtualDrive: newVirtualDrive, uponCompletion: {
                            _ in
                            complete = true
                        })
                    }
                    newVirtualDrive.path = newVirtualDrive.path + "/" + newVirtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION
                } else {
                    self.diskProgressLabel.stringValue = String(format: NSLocalizedString("CreateDiskFileViewController.updatingDisk", comment: ""), newVirtualDrive.name)
                    if self.isVirtualizaionFrameworkInUse {
                        VirtualizationFrameworkUtils.updateDiskImage(oldVirtualDrive: self.oldVirtualDrive!, newVirtualDrive: newVirtualDrive, path: NSHomeDirectory(), uponCompletion: { _ in
                            complete = true
                        })
                    } else {
                        QemuUtils.updateDiskImage(oldVirtualDrive: self.oldVirtualDrive!, newVirtualDrive: newVirtualDrive, path: NSHomeDirectory(), uponCompletion: { _ in
                            complete = true
                        })
                    }
                }
            }

            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in

                guard !complete else {
                    timer.invalidate()
                    self.progressBar.stopAnimation(self)
                    self.dismiss(self)

                    self.parentController!.diskCreated()
                    return
                }
            })
        }
    }
}
