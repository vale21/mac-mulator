//
//  VirtualMachineTableCellView.swift
//  MacMulator
//
//  Created by Vale on 28/01/21.
//

import Cocoa

class VirtualMachineTableCellView: NSTableCellView, NSTextFieldDelegate {
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

    private var renameCompletion: ((String) -> Void)?
    private var renameCancelled = false

    /// Turns the name into an editable field, like renaming a file in Finder.
    /// The completion is called with the new name when the edit is confirmed.
    func beginRenaming(completion: @escaping (String) -> Void) {
        guard let virtualMachine, renameCompletion == nil else { return }
        renameCompletion = completion
        renameCancelled = false
        vmName.stringValue = virtualMachine.displayName
        vmName.delegate = self
        vmName.isEditable = true
        vmName.isSelectable = true
        // Becoming first responder selects the whole name.
        window?.makeFirstResponder(vmName)
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            renameCancelled = true
            window?.makeFirstResponder(enclosingTableView)
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_: Notification) {
        guard let completion = renameCompletion else { return }
        renameCompletion = nil
        vmName.isEditable = false
        vmName.isSelectable = false
        vmName.delegate = nil

        let newName = vmName.stringValue.trimmingCharacters(in: .whitespaces)
        // Restore the regular label (it also adds the template suffix).
        if let virtualMachine, let rootController {
            refresh(state: VirtualMachineTableCellView.computeVMState(virtualMachine, rootController))
        }
        window?.makeFirstResponder(enclosingTableView)

        if !renameCancelled, !newName.isEmpty, newName != virtualMachine?.displayName {
            completion(newName)
        }
    }

    private var enclosingTableView: NSTableView? {
        var current: NSView? = superview
        while let view = current {
            if let table = view as? NSTableView {
                return table
            }
            current = view.superview
        }
        return nil
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
