//
//  EditVMViewControllerSnapshots.swift
//  MacMulator
//
//  Created by Vale on 08/06/2026.
//

import Cocoa

class EditVMViewControllerSnapshots: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet var snapshotsTableView: NSTableView!
    @IBOutlet var snapshotTitleLabel: NSTextField!
    @IBOutlet var snapshotScreenshotView: NSImageView!
    @IBOutlet var snapshotDescriptionScrollView: NSScrollView!
    @IBOutlet var snapshotDescriptionTextView: NSTextView!
    @IBOutlet var newSnapshotButton: NSButton!
    @IBOutlet var restoreButton: NSButton!
    @IBOutlet var deleteButton: NSButton!

    var virtualMachine: VirtualMachine?
    var currentSnapshot: VirtualMachineSnapshot? = nil

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        updateView()
    }

    @IBAction func createNewSnapshot(_: Any) {}

    @IBAction func restoreFromSnapshot(_: Any) {}

    @IBAction func deleteSnapshot(_: Any) {
        let response = Utils.showPrompt(window: view.window!, style: NSAlert.Style.informational, message: "Are you sure you want to delete snapshot \(currentSnapshot!.name)?", virtualMachine: virtualMachine)
        if response.rawValue == Utils.ALERT_RESP_OK {
            virtualMachine?.removeSnapshot(currentSnapshot!.timestamp)
            currentSnapshot = nil
            updateView()
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self)

        if let virtualMachine {
            if let snapshots = virtualMachine.snapshots {
                let snapshot = snapshots[row]
                if let cell = cell as? NSTableCellView {
                    cell.textField?.stringValue = snapshot.name + " (" + formatTimestamp(snapshot) + ")"
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
            updateView()
        }
    }

    fileprivate func updateView() {
        snapshotsTableView.reloadData()
        if let currentSnapshot {
            snapshotScreenshotView.isHidden = false
            snapshotDescriptionScrollView.isHidden = false
            restoreButton.isHidden = false
            deleteButton.isHidden = false

            snapshotTitleLabel.stringValue = currentSnapshot.name + " (" + formatTimestamp(currentSnapshot) + ")"
            snapshotScreenshotView.image = NSImage(contentsOf: NSURL.fileURL(withPath: currentSnapshot.screenshotPath))
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
