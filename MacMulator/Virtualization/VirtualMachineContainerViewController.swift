//
//  VirtualMachineContainerViewController.swift
//  MacMulator
//
//  Created by Vale on 14/04/22.
//

import Cocoa
import Virtualization

class BusyViewInformation {
    let operation: String
    let dismissalCriteria: () -> Bool
    let alertMessage: String?

    init(operation: String, dismissalCriteria: @escaping () -> Bool, alertMessage: String?) {
        self.operation = operation
        self.dismissalCriteria = dismissalCriteria
        self.alertMessage = alertMessage
    }
}

@available(macOS 12.0, *)
class VirtualMachineContainerViewController: RunningVMManagerViewController {
    override func viewDidAppear() {
        super.viewDidAppear()

        if let virtualMachine {
            if let vmRunner {
                let runner = vmRunner as! VirtualizationFrameworkVirtualMachineRunner
                runner.setVmView(view as! VZVirtualMachineView)
                runner.setVmViewController(self)
                runner.runVM(recoveryMode: recoveryMode, uponCompletion: {
                    result, _ in
                    DispatchQueue.main.async {
                        if result.exitCode != 0 {
                            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("VirtualMachineContainerViewController.vmExecutionError", comment: ""), result.error!), virtualMachine: virtualMachine)
                        }
                    }
                })
            }
        }
    }

    func showPausingView() {
        performSegue(withIdentifier: MacMulatorConstants.SHOW_PAUSE_RESUME_VM_SEGUE, sender: BusyViewInformation(operation: "Pausing", dismissalCriteria: { false }, alertMessage: nil))
    }

    func showResumingView() {
        performSegue(withIdentifier: MacMulatorConstants.SHOW_PAUSE_RESUME_VM_SEGUE, sender: BusyViewInformation(operation: "Resuming", dismissalCriteria: vmRunner?.isVMRunning ?? { true }, alertMessage: nil))
    }

    func showSnapshottingView() {
        performSegue(withIdentifier: MacMulatorConstants.SHOW_PAUSE_RESUME_VM_SEGUE, sender: BusyViewInformation(operation: "Snapshotting", dismissalCriteria: vmRunner?.isVMRunning ?? { true }, alertMessage: NSLocalizedString("VirtualMachineContainerViewController.snapshotCreated", comment: "")))
    }

    func showRestoringView() {
        performSegue(withIdentifier: MacMulatorConstants.SHOW_PAUSE_RESUME_VM_SEGUE, sender: BusyViewInformation(operation: "Restoring snapshot", dismissalCriteria: vmRunner?.isVMRunning ?? { true }, alertMessage: NSLocalizedString("VirtualMachineContainerViewController.snapshotRestored", comment: "")))
    }

    func windowDidEnterFullScreen(_: Notification) {
        isFullScreen = true
    }

    func windowDidExitFullScreen(_: Notification) {
        isFullScreen = false
    }

    func takeScreenshot() {
        let win = view.window
        if let window = win {
            do {
                let inf = CGFloat(FP_INFINITE)
                let null = CGRect(x: inf, y: inf, width: 0, height: 0)
                let cgImage = CGWindowListCreateImage(null, .optionIncludingWindow, CGWindowID(window.windowNumber), .bestResolution)
                let image = NSImage(cgImage: cgImage!, size: view.bounds.size)
                let imageRep = NSBitmapImageRep(data: image.tiffRepresentation!)
                let pngData = imageRep?.representation(using: .png, properties: [:])
                try pngData?.write(to: URL(fileURLWithPath: virtualMachine!.path + "/" + MacMulatorConstants.SCREENSHOT_FILE_NAME))
            } catch {}
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == MacMulatorConstants.SHOW_INSTALLING_OS_SEGUE {
            let destinationController = segue.destinationController as! VirtualizationFrameworkInstallVMViewController
            if let vmRunner {
                let runner = vmRunner as! VirtualizationFrameworkVirtualMachineRunner
                destinationController.setParentRunner(runner)
                destinationController.setVirtualMachine(runner.vzVirtualMachine!)
                let installDrive = Utils.findIPSWInstallDrive(runner.managedVm.drives)
                if installDrive != nil {
                    destinationController.setRestoreImageURL(URL(fileURLWithPath: installDrive!.path))
                }
            }
        } else if segue.identifier == MacMulatorConstants.SHOW_PAUSE_RESUME_VM_SEGUE {
            let destinationController = segue.destinationController as! VirtualizationFrameworkPauseResumeVMViewController
            if let vmRunner {
                let runner = vmRunner as! VirtualizationFrameworkVirtualMachineRunner
                destinationController.setParentRunner(runner)
                destinationController.setOperation((sender as! BusyViewInformation).operation)
                destinationController.setDismissalCriteria((sender as! BusyViewInformation).dismissalCriteria)
                destinationController.setAlertMessage((sender as! BusyViewInformation).alertMessage)
            }
        }
    }
}
