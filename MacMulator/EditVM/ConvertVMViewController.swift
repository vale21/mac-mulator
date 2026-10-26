import Cocoa

@available(macOS 13.0, *)
class ConvertVMViewController: NSViewController {
    @IBOutlet var convertingVMLabel: NSTextField!
    @IBOutlet var progressBar: NSProgressIndicator!
    @IBOutlet var estimateTimeRemainingLabel: NSTextField!

    var parentController: VirtualMachineViewController?
    var virtualMachine: VirtualMachine?

    func setParentController(_ parentController: VirtualMachineViewController) {
        self.parentController = parentController
    }

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
    }

    override func viewDidAppear() {
        convertingVMLabel.stringValue = NSLocalizedString("ConvertVMViewController.convertingVM", comment: "")
        progressBar.startAnimation(self)
        setEstimateTimeRemainingVisible(false)

        if let virtualMachine {
            var complete = false
            var error: String? = nil

            if let currentVm = self.virtualMachine {
                if currentVm.type == MacMulatorConstants.APPLE_VM {
                    let drives = currentVm.drives.filter { ($0.mediaType == QemuConstants.MEDIATYPE_DISK || $0.mediaType == QemuConstants.MEDIATYPE_NVME) && $0.format == QemuConstants.FORMAT_ASIF }
                    convertDrives(drives, of: currentVm, to: QemuConstants.FORMAT_QCOW2) { code, message in
                        if code == 0 {
                            QemuUtils.createAuxiliaryDriveFilesOnDisk(currentVm)
                            VirtualizationFrameworkLinuxSupport.deleteLinuxVirtualMachineData(vm: currentVm)
                            currentVm.type = MacMulatorConstants.QEMU_VM
                            currentVm.writeToPlist()
                            complete = true
                        } else {
                            complete = true
                            error = message
                        }
                    }
                } else {
                    let drives = currentVm.drives.filter { ($0.mediaType == QemuConstants.MEDIATYPE_DISK || $0.mediaType == QemuConstants.MEDIATYPE_NVME) && $0.format == QemuConstants.FORMAT_QCOW2 }
                    let targetFormat: String
                    if #available(macOS 26.0, *) {
                        targetFormat = QemuConstants.FORMAT_ASIF
                    } else {
                        targetFormat = QemuConstants.FORMAT_RAW
                    }
                    convertDrives(drives, of: currentVm, to: targetFormat) { code, message in
                        if code == 0 {
                            VirtualizationFrameworkLinuxSupport.createLinuxVirtualMachineData(vm: currentVm)
                            QemuUtils.deleteAuxiliaryDriveFilesOnDisk(currentVm)
                            currentVm.type = MacMulatorConstants.APPLE_VM
                            currentVm.writeToPlist()
                            complete = true
                        } else {
                            complete = true
                            error = message
                        }
                    }
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
                        self.parentController?.vmConverted(virtualMachine)
                    } else {
                        self.parentController?.vmFailedConversion(virtualMachine, error ?? "")
                    }
                    return
                }
            })
        }
    }

    private func convertDrives(_ drives: [VirtualDrive], of vm: VirtualMachine, to format: String, totalDrives: Int? = nil, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        guard let drive = drives.first else {
            callback(0, nil)
            return
        }

        let totalDrives = totalDrives ?? drives.count
        let index = totalDrives - drives.count
        let progress: (Double) -> Void = { percentage in
            self.updateProgress((Double(index) * 100 + percentage) / Double(totalDrives))
        }

        convertDrive(drive, to: format, in: vm.path, progress: progress) { code, message in
            DispatchQueue.main.async {
                vm.writeToPlist()
                if code == 0 {
                    self.convertDrives(Array(drives.dropFirst()), of: vm, to: format, totalDrives: totalDrives, uponCompletion: callback)
                } else {
                    callback(code, message)
                }
            }
        }
    }

    private func convertDrive(_ drive: VirtualDrive, to format: String, in path: String, progress: @escaping (Double) -> Void, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let originalFormat = drive.format
        let factory = DiskImageManagerFactory()
        let sourceManager = factory.create(isVirtualizationFrameworkInUse: originalFormat == QemuConstants.FORMAT_ASIF)
        let targetManager = factory.create(isVirtualizationFrameworkInUse: format == QemuConstants.FORMAT_ASIF)

        drive.format = QemuConstants.FORMAT_RAW
        sourceManager.convertDiskImage(drive, path, fromFormat: originalFormat, progress: { progress($0 / 2) }, uponCompletion: { code, message in
            guard code == 0 else {
                drive.format = originalFormat
                callback(code, message)
                return
            }

            drive.format = format
            targetManager.convertDiskImage(drive, path, fromFormat: QemuConstants.FORMAT_RAW, progress: { progress(50 + $0 / 2) }, uponCompletion: { code, message in
                if code != 0 {
                    drive.format = QemuConstants.FORMAT_RAW
                }
                callback(code, message)
            })
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
        DispatchQueue.main.async {
            let bar = self.progressBar!
            if bar.isIndeterminate {
                bar.stopAnimation(self)
                bar.isIndeterminate = false
                bar.minValue = 0
                bar.maxValue = 100

                self.setEstimateTimeRemainingVisible(true)
                self.estimateTimeRemainingLabel.stringValue = NSLocalizedString("CreateVMFileViewController.timeRemainingCalculating", comment: "")
            }
            bar.doubleValue = percentage
        }
    }
}
