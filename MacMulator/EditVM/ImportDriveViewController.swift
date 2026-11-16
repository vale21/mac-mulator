//
//  ImportDriveViewController.swift
//  MacMulator
//
//  Created by Vale on 16/11/2026.
//

import Cocoa

/// Copies (or converts) a disk image into the VM bundle, showing the progress and the estimated time remaining
class ImportDriveViewController: NSViewController {
    @IBOutlet var importProgressLabel: NSTextField!
    @IBOutlet var progressBar: NSProgressIndicator!
    @IBOutlet var estimateTimeRemainingLabel: NSTextField!

    var sourcePath: String?
    var details: DiskImageDetails?
    var virtualDrive: VirtualDrive?
    var virtualMachine: VirtualMachine?
    var parentController: EditVMViewControllerHardware?

    func setImport(from sourcePath: String, details: DiskImageDetails, into virtualDrive: VirtualDrive, of virtualMachine: VirtualMachine) {
        self.sourcePath = sourcePath
        self.details = details
        self.virtualDrive = virtualDrive
        self.virtualMachine = virtualMachine
    }

    func setParentController(_ parentController: EditVMViewControllerHardware) {
        self.parentController = parentController
    }

    override func viewDidAppear() {
        progressBar.startAnimation(self)
        setEstimateTimeRemainingVisible(false)

        guard let sourcePath, let details, let virtualDrive, let virtualMachine else { return }
        importProgressLabel.stringValue = String(format: NSLocalizedString("ImportDriveViewController.importingDrive", comment: ""), (sourcePath as NSString).lastPathComponent)

        var complete = false
        var error: String? = nil
        let finish: (Int32, String?) -> Void = { errorCode, errorMessage in
            DispatchQueue.main.async {
                error = errorCode != 0 ? (errorMessage ?? "") : nil
                complete = true
            }
        }

        // qemu-img does not write ASIF: the image is imported as RAW, then converted by the Virtualization framework manager
        let convertsToAsif = virtualDrive.format == QemuConstants.FORMAT_ASIF
        let importScale = convertsToAsif ? 0.5 : 1.0
        QemuDiskImageManager().importDiskImage(from: sourcePath, details: details, to: virtualDrive.path, targetFormat: convertsToAsif ? QemuConstants.FORMAT_RAW : virtualDrive.format, qemuPath: QemuUtils.getQemuPath(for: virtualMachine), progress: { percentage in
            DispatchQueue.main.async {
                self.updateProgress(percentage * importScale)
            }
        }, uponCompletion: { errorCode, errorMessage in
            guard errorCode == 0, convertsToAsif else {
                finish(errorCode, errorMessage)
                return
            }
            VirtualizationFrameworkDiskImageManager().convertDiskImage(virtualDrive, virtualMachine.path, fromFormat: QemuConstants.FORMAT_RAW, progress: { percentage in
                DispatchQueue.main.async {
                    self.updateProgress(50 + percentage / 2)
                }
            }, uponCompletion: { errorCode, errorMessage in
                if errorCode != 0 {
                    try? FileManager.default.removeItem(atPath: virtualDrive.path)
                }
                finish(errorCode, errorMessage)
            })
        })

        let startTime = Int64(Date().timeIntervalSince1970)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
            if !complete {
                let progress = self.progressBar.doubleValue
                if !self.progressBar.isIndeterminate, progress > 10 {
                    self.estimateTimeRemainingLabel.stringValue = String(format: NSLocalizedString("CreateVMFileViewController.estimateTimeRemaining", comment: ""), Utils.computeTimeRemaining(startTime: startTime, progress: progress))
                }
            } else {
                timer.invalidate()
                self.progressBar.stopAnimation(self)
                self.dismiss(self)

                if let error {
                    self.parentController?.driveImportFailed(error: error)
                } else {
                    self.parentController?.driveImported(virtualDrive)
                }
            }
        })
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
