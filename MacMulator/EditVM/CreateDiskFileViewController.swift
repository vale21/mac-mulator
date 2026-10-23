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
    @IBOutlet var estimateTimeRemainingLabel: NSTextField!

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
        setEstimateTimeRemainingVisible(false)

        if let newVirtualDrive {
            var complete = false
            var error: String? = nil

            _ = DispatchQueue(label: "New Disk Thread", qos: DispatchQoS.background)
            DispatchQueue.main.async {
                let diskImageManager = DiskImageManagerFactory().create(isVirtualizationFrameworkInUse: self.isVirtualizaionFrameworkInUse)
                if self.parentController?.mode == NewDiskViewController.Mode.ADD {
                    self.diskProgressLabel.stringValue = NSLocalizedString("CreateDiskFileViewController.creatingDisk", comment: "")
                    diskImageManager.createDiskImage(newVirtualDrive, newVirtualDrive.path, uponCompletion: {
                        errorCode, errorMessage in
                        complete = true
                        error = errorCode != 0 ? errorMessage : nil
                    })
                    newVirtualDrive.path = newVirtualDrive.path + "/" + newVirtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION
                } else {
                    self.diskProgressLabel.stringValue = String(format: NSLocalizedString("CreateDiskFileViewController.updatingDisk", comment: ""), newVirtualDrive.name)
                    diskImageManager.updateDiskImage(oldVirtualDrive: self.oldVirtualDrive!, newVirtualDrive: newVirtualDrive, path: NSHomeDirectory(), progress: { percentage in
                        DispatchQueue.main.async {
                            self.updateProgress(percentage)
                        }
                    }, uponCompletion: { errorCode, errorMessage in
                        complete = true
                        error = errorCode != 0 ? errorMessage : nil
                    })
                }
            }

            let startTime = Int64(Date().timeIntervalSince1970)
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in

                if !complete, !self.progressBar.isIndeterminate {
                    let progress = self.progressBar.doubleValue
                    if progress > 10 {
                        self.estimateTimeRemainingLabel.stringValue = String(format: NSLocalizedString("CreateVMFileViewController.estimateTimeRemaining", comment: ""), Utils.computeTimeRemaining(startTime: startTime, progress: self.progressBar.doubleValue))
                    }
                } else {
                    timer.invalidate()
                    self.progressBar.stopAnimation(self)
                    self.dismiss(self)

                    if error == nil {
                        self.parentController!.diskCreated()
                    } else {
                        self.parentController!.diskFailedCreation(error: error ?? "")
                    }
                    return
                }
            })
        }
    }

    private func setEstimateTimeRemainingVisible(_ visible: Bool) {
        estimateTimeRemainingLabel.isHidden = !visible
        let size = NSSize(width: view.frame.width, height: visible ? 107 : 82)
        if let window = view.window {
            // Subviews are pinned to the top, so keep the top edge fixed while resizing.
            var frame = window.frame
            let newHeight = window.frameRect(forContentRect: NSRect(origin: .zero, size: size)).height
            frame.origin.y += frame.height - newHeight
            frame.size.height = newHeight
            window.setFrame(frame, display: true, animate: true)
        } else {
            preferredContentSize = size
        }
    }

    private func updateProgress(_ percentage: Double) {
        if progressBar.isIndeterminate {
            progressBar.stopAnimation(self)
            progressBar.isIndeterminate = false
            progressBar.minValue = 0
            progressBar.maxValue = 100

            setEstimateTimeRemainingVisible(true)
            estimateTimeRemainingLabel.stringValue = NSLocalizedString("CreateVMFileViewController.timeRemainingCalculating", comment: "")
        }
        progressBar.doubleValue = percentage
    }
}
