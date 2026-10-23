import Cocoa

@available(macOS 14.0, *)
class ConvertVMViewController: NSViewController {
    @IBOutlet var convertingVMLabel: NSTextField!
    @IBOutlet var convertingVMProgressBar: NSProgressIndicator!

    var parentController: VirtualMachineViewController?
    var virtualMachine: VirtualMachine?

    func setParentController(_ parentController: VirtualMachineViewController) {
        self.parentController = parentController
    }

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
    }

    override func viewDidAppear() {
        convertingVMProgressBar.startAnimation(self)

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
                    convertDrives(drives, of: currentVm, to: QemuConstants.FORMAT_ASIF) { code, message in
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

            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in

                guard !complete else {
                    timer.invalidate()
                    self.convertingVMProgressBar.stopAnimation(self)
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

    private func convertDrives(_ drives: [VirtualDrive], of vm: VirtualMachine, to format: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        guard let drive = drives.first else {
            callback(0, nil)
            return
        }

        convertDrive(drive, to: format, in: vm.path) { code, message in
            DispatchQueue.main.async {
                vm.writeToPlist()
                if code == 0 {
                    self.convertDrives(Array(drives.dropFirst()), of: vm, to: format, uponCompletion: callback)
                } else {
                    callback(code, message)
                }
            }
        }
    }

    private func convertDrive(_ drive: VirtualDrive, to format: String, in path: String, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let originalFormat = drive.format
        let factory = DiskImageManagerFactory()
        let sourceManager = factory.create(isVirtualizationFrameworkInUse: originalFormat == QemuConstants.FORMAT_ASIF)
        let targetManager = factory.create(isVirtualizationFrameworkInUse: format == QemuConstants.FORMAT_ASIF)

        drive.format = QemuConstants.FORMAT_RAW
        sourceManager.convertDiskImage(drive, path, fromFormat: originalFormat, progress: nil, uponCompletion: { code, message in
            guard code == 0 else {
                drive.format = originalFormat
                callback(code, message)
                return
            }

            drive.format = format
            targetManager.convertDiskImage(drive, path, fromFormat: QemuConstants.FORMAT_RAW, progress: nil, uponCompletion: { code, message in
                if code != 0 {
                    drive.format = QemuConstants.FORMAT_RAW
                }
                callback(code, message)
            })
        })
    }
}
