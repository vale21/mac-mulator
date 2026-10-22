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
            var error = false

            let dispatchQueue = DispatchQueue(label: "New Disk Thread", qos: DispatchQoS.background)
            DispatchQueue.main.async {
                let diskImageManager = DiskImageManagerFactory().create(isVirtualizationFrameworkInUse: self.isVirtualizaionFrameworkInUse)
                if self.parentController?.mode == NewDiskViewController.Mode.ADD {
                    self.diskProgressLabel.stringValue = NSLocalizedString("CreateDiskFileViewController.creatingDisk", comment: "")
                    diskImageManager.createDiskImage(newVirtualDrive, newVirtualDrive.path, uponCompletion: {
                        code in
                        complete = true
                        error = code != 0
                    })
                    newVirtualDrive.path = newVirtualDrive.path + "/" + newVirtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION
                } else {
                    self.diskProgressLabel.stringValue = String(format: NSLocalizedString("CreateDiskFileViewController.updatingDisk", comment: ""), newVirtualDrive.name)
                    diskImageManager.updateDiskImage(oldVirtualDrive: self.oldVirtualDrive!, newVirtualDrive: newVirtualDrive, path: NSHomeDirectory(), progress: { percentage in
                        DispatchQueue.main.async {
                            self.updateProgress(percentage)
                        }
                    }, uponCompletion: { code in
                        complete = true
                        error = code != 0
                    })
                }
            }

            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in

                guard !complete else {
                    timer.invalidate()
                    self.progressBar.stopAnimation(self)
                    self.dismiss(self)

                    if !error {
                        self.parentController!.diskCreated()
                    } else {
                        self.parentController!.diskFailedCreation()
                    }
                    return
                }
            })
        }
    }

    private func updateProgress(_ percentage: Double) {
        if progressBar.isIndeterminate {
            progressBar.stopAnimation(self)
            progressBar.isIndeterminate = false
            progressBar.minValue = 0
            progressBar.maxValue = 100
        }
        progressBar.doubleValue = percentage
    }
}
