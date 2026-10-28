//
//  VirtualMachineTableCellView.swift
//  MacMulator
//
//  Created by Vale on 28/01/21.
//

import Cocoa

class VirtualMachineTableCellView: NSTableCellView {
    enum CellState {
        case running
        case paused
        case stopped
        case template
    }

    @IBOutlet var vmName: NSTextField!
    @IBOutlet var vmIcon: NSImageView!
    @IBOutlet var runningSpinner: NSProgressIndicator!

    private var virtualMachine: VirtualMachine?
    private var rootController: RootViewController?

    func setRootController(_ rootController: RootViewController) {
        self.rootController = rootController
    }

    func setVirtualMachine(virtualMachine: VirtualMachine) {
        self.virtualMachine = virtualMachine
        if let rootController {
            setState(VirtualMachineTableCellView.computeVMState(virtualMachine, rootController))
        }
    }

    func setState(_ state: CellState) {
        if state == .running {
            runningSpinner.isHidden = false
            runningSpinner.startAnimation(self)
            vmIcon.isHidden = true
        } else if state == .paused || state == .stopped || state == .template {
            runningSpinner.isHidden = true
            runningSpinner.stopAnimation(self)
            vmIcon.isHidden = false
        }
        refresh(state: state)
    }

    func refresh(state: CellState) {
        if let virtualMachine {
            if Utils.isVMTemplate(virtualMachine) {
                vmName.stringValue = virtualMachine.displayName + " (VM template)"
            } else {
                vmName.stringValue = virtualMachine.displayName
            }

            let backgroundImageName = Utils.getIconForSubType(virtualMachine.os, virtualMachine.subtype) + ".small"
            if state == .paused {
                if let newImage = Utils.getIconWithOverlay(backgroundImageName, "pause.overlay") {
                    vmIcon.image = newImage
                }
            } else if state == .template {
                if let newImage = Utils.getIconWithOverlay(backgroundImageName, "template.overlay.small") {
                    vmIcon.image = newImage
                }
            } else {
                vmIcon.image = NSImage(named: NSImage.Name(backgroundImageName))
            }
        }
    }

    static func computeVMState(_ virtualMachine: VirtualMachine, _ rootController: RootViewController) -> CellState {
        if Utils.isVMTemplate(virtualMachine) {
            CellState.template
        } else if rootController.isVMRunning(virtualMachine) == true {
            CellState.running
        } else if rootController.isVMPaused(virtualMachine) == true {
            CellState.paused
        } else {
            CellState.stopped
        }
    }
}
