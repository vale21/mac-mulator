//
//  RunningVMManagerViewController.swift
//  MacMulator
//
//  Created by Vale on 06/10/2026.
//

import Cocoa

class RunningVMManagerViewController: NSViewController, NSWindowDelegate {
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
        }
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        let response = Utils.showPrompt(window: view.window!, style: NSAlert.Style.warning, message: NSLocalizedString("VirtualMachineContainerViewController.forciblyClosing", comment: ""), virtualMachine: virtualMachine)
        if response.rawValue != Utils.ALERT_RESP_OK {
            return false
        } else {
            stopVM(false)
            return true
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
}
