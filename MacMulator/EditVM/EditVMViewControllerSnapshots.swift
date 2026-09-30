//
//  EditVMViewControllerSnapshots.swift
//  MacMulator
//
//  Created by Vale on 08/06/2026.
//

import Cocoa

class EditVMViewControllerSnapshots: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate {
    @IBOutlet var snapshotsTableView: NSTableView!
    @IBOutlet var snapshotTitleLabel: NSTextField!
    @IBOutlet var snapshotScreenshotView: NSImageView!
    @IBOutlet var snapshotDescriptionScrollView: NSScrollView!
    @IBOutlet var snapshotDescriptionTextView: NSTextView!
    @IBOutlet var newSnapshotButton: NSButton!
    @IBOutlet var restoreButton: NSButton!
    @IBOutlet var deleteButton: NSButton!

    var currentSnapshot: VirtualMachineSnapshot? = nil
    var virtualMachine: VirtualMachine?
    var vmRunner: VirtualMachineRunner?

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        updateView()
    }

    func setVmRunner(_ vmRunner: VirtualMachineRunner) {
        self.vmRunner = vmRunner
    }

    @IBAction func createNewSnapshot(_: Any) {
        do {
            try vmRunner?.createVMSnapshot { snapshot in
                self.currentSnapshot = snapshot
                if !(snapshot?.running ?? false) {
                    Utils.showAlert(window: self.view.window!, style: NSAlert.Style.informational, message: "VM Snapshot created successfully!", virtualMachine: self.virtualMachine)
                }
                self.updateView()
            }
        } catch {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: "Could not create VM snapshot", virtualMachine: virtualMachine)
        }
    }

    @IBAction func restoreFromSnapshot(_: Any) {
        if let snapshot = currentSnapshot {
            do {
                try vmRunner?.restoreVMSnapshot(snapshot: snapshot, nil)
                updateView()
            } catch {
                Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: "Could not create VM snapshot", virtualMachine: virtualMachine)
            }
        }
    }

    func snapshotDeleted() {
        currentSnapshot = nil
        updateView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self)

        if let virtualMachine {
            if let snapshots = virtualMachine.snapshots {
                let snapshot = snapshots[row]
                if let cell = cell as? NSTableCellView {
                    cell.textField?.stringValue = formatTimestamp(snapshot) + " - " + (snapshot.running ? "Live" : "At rest")
                }
            }
        }
        return cell
    }

    func numberOfRows(in _: NSTableView) -> Int {
        if let virtualMachine {
            return virtualMachine.snapshots?.count ?? 0
        }
        return 0
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            currentSnapshot = virtualMachine?.snapshots?[selectedRow]
        } else {
            currentSnapshot = nil
        }

        updateDetails()
    }

    func textDidChange(_: Notification) {
        currentSnapshot?.description = snapshotDescriptionTextView.string
    }

    override func shouldPerformSegue(withIdentifier identifier: NSStoryboardSegue.Identifier, sender _: Any?) -> Bool {
        if identifier == MacMulatorConstants.DELETE_SNAPSHOT_SEGUE {
            let message = "Are you sure you want to delete this snapshot? This operation cannot be undone."
            let response = Utils.showPrompt(window: view.window!, style: NSAlert.Style.warning, message: message, virtualMachine: virtualMachine)
            return response.rawValue == Utils.ALERT_RESP_OK
        }
        return true
    }

    override func prepare(for segue: NSStoryboardSegue, sender _: Any?) {
        if segue.identifier == MacMulatorConstants.DELETE_SNAPSHOT_SEGUE {
            let destinationController = segue.destinationController as! DeleteSnapshotViewController
            destinationController.setSnapshot(currentSnapshot)
            destinationController.setVmRunner(vmRunner)
            destinationController.setParentController(self)
        }
    }

    fileprivate func updateView() {
        snapshotsTableView.reloadData()
        if let currentSnapshot, let index = virtualMachine?.snapshots?.firstIndex(of: currentSnapshot) {
            snapshotsTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else {
            snapshotsTableView.deselectAll(nil)
        }
        updateDetails()
    }

    fileprivate func updateDetails() {
        if let currentSnapshot {
            snapshotScreenshotView.isHidden = false
            snapshotDescriptionScrollView.isHidden = false
            restoreButton.isHidden = false
            deleteButton.isHidden = false

            snapshotTitleLabel.stringValue = (currentSnapshot.running ? "Live " : "At rest ") + "snapshot - " + currentSnapshot.name + formatTimestamp(currentSnapshot)
            if let screenshotPath = currentSnapshot.screenshotPath {
                snapshotScreenshotView.image = NSImage(contentsOf: NSURL.fileURL(withPath: screenshotPath))
            } else {
                snapshotScreenshotView.image = nil
            }
            snapshotDescriptionTextView.string = currentSnapshot.description
        } else {
            snapshotTitleLabel.stringValue = "Please select a snapshot from the table on the left"
            snapshotScreenshotView.isHidden = true
            snapshotDescriptionScrollView.isHidden = true
            restoreButton.isHidden = true
            deleteButton.isHidden = true
        }
    }

    fileprivate func formatTimestamp(_ snapshot: VirtualMachineSnapshot) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(snapshot.timestamp) / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
