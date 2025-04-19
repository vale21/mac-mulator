//
//  VirtualMachineContainerViewController.swift
//  MacMulator
//
//  Created by Vale on 14/04/22.
//

import Cocoa
import Virtualization

@available(macOS 12.0, *)
class VirtualMachineContainerViewController: NSViewController, NSWindowDelegate, RunningVMManagerViewController {
    var virtualMachine: VirtualMachine?
    var recoveryMode: Bool = false
    var vmController: VirtualMachineViewController?
    var vmRunner: VirtualMachineRunner?
    var isFullScreen = false

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
    }

    func setRecoveryMode(_ recoveryMode: Bool) {
        self.recoveryMode = recoveryMode
    }

    func setVmController(_ controller: VirtualMachineViewController) {
        vmController = controller
    }

    func setVmRunner(_ runner: VirtualMachineRunner) {
        vmRunner = runner
    }

    override func viewDidAppear() {
        view.window?.delegate = self
        view.window?.title = (virtualMachine?.displayName ?? "") + " - MacMulator"
        view.window?.minSize = NSSize(width: 800, height: 600)

        if let virtualMachine {
            let resolution = Utils.getResolutionElements(virtualMachine.displayResolution)
            var origin: [String] = []
            if let displayOrigin = virtualMachine.displayOrigin {
                origin = Utils.getOriginElements(displayOrigin)
            }
            view.window?.setContentSize(CGSize(width: resolution[0], height: resolution[1]))

            if origin.isEmpty || (origin[0] == "c" && origin[1] == "c") {
                view.window?.center()
            } else if origin[0] == "f", origin[1] == "f" {
                view.window?.toggleFullScreen(self)
                isFullScreen = true
            } else {
                view.window?.setFrameOrigin(NSPoint(x: Double(origin[0])!, y: Double(origin[1])!))
            }

            if let vmRunner {
                let runner = vmRunner as! VirtualizationFrameworkVirtualMachineRunner
                runner.setVmView(view as! VZVirtualMachineView)
                runner.setVmViewController(self)
                runner.runVM(recoveryMode: recoveryMode, uponCompletion: {
                    result, _ in
                    DispatchQueue.main.async {
                        if result.exitCode != 0 {
                            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: "VM execution failed with error: " + result.error!)
                        }
                    }
                })
            }
        }
    }

    func showPausingView() {
        performSegue(withIdentifier: MacMulatorConstants.SHOW_PAUSE_RESUME_VM_SEGUE, sender: "Pausing")
    }

    func showResumingView() {
        performSegue(withIdentifier: MacMulatorConstants.SHOW_PAUSE_RESUME_VM_SEGUE, sender: "Resuming")
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        if Utils.isPauseSupported(vmRunner!.getManagedVM()) {
            pauseVM()

            // Window will be closed by the VM runner after the pausing will be complete
            return false
        } else {
            let response = Utils.showPrompt(window: view.window!, style: NSAlert.Style.warning, message: "Closing this window will forcibly kill the running VM.\nIt is strogly suggested to shut it down gracefully using the guest OS shut down procedure, or you might loose your unsaved work.\n\nDo you want to continue?")
            if response.rawValue != Utils.ALERT_RESP_OK {
                return false
            } else {
                stopVM(false)
                return true
            }
        }
    }

    func windowWillClose(_: Notification) {
        let content = view.window!.contentView!.frame
        let window = view.window!.frame
        let resolution = "\(Int(content.width))x\(Int(content.height))x32"
        let origin = isFullScreen ? "f;f" : "\(Int(window.origin.x));\(Int(window.origin.y))"

        virtualMachine?.displayResolution = resolution
        virtualMachine?.displayOrigin = origin
        virtualMachine?.writeToPlist()
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

    func stopVM(_ closeWindow: Bool) {
        if let vmRunner {
            if vmRunner.isVMRunning() {
                vmRunner.stopVM(guestStopped: closeWindow)
            }
        }
        if let virtualMachine {
            vmController?.cleanupStoppedVM(virtualMachine)
        }
        if closeWindow {
            view.window?.close()
        }
    }

    func pauseVM() {
        vmRunner?.pauseVM()
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
                destinationController.setOperation(sender as! String)
            }
        }
    }
}
