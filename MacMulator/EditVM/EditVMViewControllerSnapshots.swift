//
//  EditVMViewControllerSnapshots.swift
//  MacMulator
//
//  Created by Vale on 08/06/2026.
//

import Cocoa

class EditVMViewControllerSnapshots: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet var snapshotsTableView: NSTableView!
    @IBOutlet var snapshotScreenshotView: NSImageView!
    @IBOutlet var snapshotDescriptionTextView: NSScrollView!
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

    @IBAction func deleteSnapshot(_: Any) {}

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self)

        if let virtualMachine {
            if let snapshots = virtualMachine.snapshots {
                let snapshot = snapshots[row]
                if let cell = cell as? NSTableCellView {
                    let date = Date(timeIntervalSince1970: TimeInterval(snapshot.timestamp))
                    let formatter = DateFormatter()
                    formatter.locale = .current
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    let dateString = formatter.string(from: date)
                    cell.textField?.stringValue = snapshot.name + " (" + dateString + ")"
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

    fileprivate func updateView() {}
}
