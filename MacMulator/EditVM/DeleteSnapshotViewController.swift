//
//  DeleteSnapshotViewController.swift
//  MacMulator
//
//  Created by Vale on 23/02/21.
//

import Cocoa

class DeleteSnapshotViewController: NSViewController {
    @IBOutlet var diskProgressLabel: NSTextField!
    @IBOutlet var progressBar: NSProgressIndicator!

    var snapshot: VirtualMachineSnapshot?
    var vmRunner: VirtualMachineRunner?
    var parentController: EditVMViewControllerSnapshots?

    func setSnapshot(_ snapshot: VirtualMachineSnapshot?) {
        self.snapshot = snapshot
    }

    func setVmRunner(_ vmRunner: VirtualMachineRunner?) {
        self.vmRunner = vmRunner
    }

    func setParentController(_ parentController: EditVMViewControllerSnapshots) {
        self.parentController = parentController
    }

    override func viewDidAppear() {
        var complete = false
        progressBar.startAnimation(self)

        if let snapshot {
            do {
                try vmRunner?.deleteVMSnapshot(snapshot: snapshot)
            } catch {
                Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: "Could not delete snapshot", virtualMachine: nil)
            }
        }
        complete = true

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
            guard !complete else {
                timer.invalidate()
                self.progressBar.stopAnimation(self)
                self.dismiss(self)

                self.parentController!.snapshotDeleted()
                return
            }
        })
    }
}
