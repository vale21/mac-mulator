//
//  ManageSnapshotViewController.swift
//  MacMulator
//
//  Created by Vale on 23/02/21.
//

import Cocoa

class ManageSnapshotViewController: NSViewController {
    @IBOutlet var progressLabel: NSTextField!
    @IBOutlet var progressBar: NSProgressIndicator!

    var snapshot: VirtualMachineSnapshot?
    var vmRunner: VirtualMachineRunner?
    var parentController: EditVMViewControllerSnapshots?
    var operation: String?

    func setSnapshot(_ snapshot: VirtualMachineSnapshot?) {
        self.snapshot = snapshot
    }

    func setVmRunner(_ vmRunner: VirtualMachineRunner?) {
        self.vmRunner = vmRunner
    }

    func setParentController(_ parentController: EditVMViewControllerSnapshots) {
        self.parentController = parentController
    }

    func setOperation(_ operation: String) {
        self.operation = operation
    }

    override func viewWillAppear() {
        if operation == MacMulatorConstants.DELETE_SNAPSHOT_SEGUE {
            progressLabel.stringValue = "Deleting VM snapshot..."
        } else if operation == MacMulatorConstants.RESTORE_SNAPSHOT_SEGUE {
            progressLabel.stringValue = "Restoring VM snapshot..."
        }
    }

    override func viewDidAppear() {
        var complete = false
        var errorFound = false

        progressBar.startAnimation(self)

        if let snapshot {
            if operation == MacMulatorConstants.DELETE_SNAPSHOT_SEGUE {
                do {
                    try vmRunner?.deleteVMSnapshot(snapshot: snapshot)
                } catch {
                    errorFound = true
                    Utils.showAlert(window: (parentController?.view.window)!, style: NSAlert.Style.critical, message: "Could not delete snapshot", virtualMachine: vmRunner?.getManagedVM())
                }
            } else if operation == MacMulatorConstants.RESTORE_SNAPSHOT_SEGUE {
                do {
                    try vmRunner?.restoreVMSnapshot(snapshot: snapshot, nil)
                } catch let error as ValidationError {
                    errorFound = true
                    Utils.showAlert(window: (parentController?.view.window)!, style: NSAlert.Style.critical, message: "Could not restore VM snapshot: " + error.description, virtualMachine: vmRunner?.getManagedVM())
                } catch {
                    errorFound = true
                    Utils.showAlert(window: (parentController?.view.window)!, style: NSAlert.Style.critical, message: "Could not restore VM snapshot: " + error.localizedDescription, virtualMachine: vmRunner?.getManagedVM())
                }
            }
        }
        complete = true

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
            guard !complete else {
                timer.invalidate()
                self.progressBar.stopAnimation(self)
                self.dismiss(self)

                if !errorFound {
                    if self.operation == MacMulatorConstants.DELETE_SNAPSHOT_SEGUE {
                        self.parentController!.snapshotDeleted()
                    } else if self.operation == MacMulatorConstants.RESTORE_SNAPSHOT_SEGUE {
                        self.parentController!.snapshotRestored(showAlert: true)
                    }
                }

                return
            }
        })
    }
}
