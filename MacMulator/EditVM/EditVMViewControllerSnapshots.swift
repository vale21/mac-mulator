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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Refresh the table when a snapshot is created or deleted outside this view (e.g. via the app menu)
        NotificationCenter.default.addObserver(self, selector: #selector(snapshotsChanged(_:)), name: MacMulatorConstants.SNAPSHOTS_CHANGED_NOTIFICATION, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func snapshotsChanged(_ notification: Notification) {
        guard let changedVM = notification.object as? VirtualMachine, changedVM === virtualMachine else { return }
        DispatchQueue.main.async {
            // Drop the selection if the selected snapshot no longer exists
            if let currentSnapshot = self.currentSnapshot, !(self.virtualMachine?.snapshots?.contains(currentSnapshot) ?? false) {
                self.currentSnapshot = nil
            }
            self.updateView()
        }
    }

    override func viewWillAppear() {
        newSnapshotButton.title = NSLocalizedString("EditVMViewControllerSnapshots.createNewSnapshot", comment: "")
        restoreButton.title = NSLocalizedString("EditVMViewControllerSnapshots.restore", comment: "")
        deleteButton.title = NSLocalizedString("EditVMViewControllerSnapshots.delete", comment: "")
        snapshotsTableView.tableColumns[0].headerCell.title = NSLocalizedString("EditVMViewControllerSnapshots.availableSnapshots", comment: "")
    }

    @IBAction func createNewSnapshot(_: Any) {
        do {
            try vmRunner?.createVMSnapshot { snapshot in
                self.currentSnapshot = snapshot
                if !(snapshot?.running ?? false) {
                    Utils.showAlert(window: self.view.window!, style: NSAlert.Style.informational, message: NSLocalizedString("EditVMViewControllerSnapshots.snapshotCreatedSuccessfully", comment: ""), virtualMachine: self.virtualMachine)
                }
                self.updateView()
            }
        } catch let error as ValidationError {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("EditVMViewControllerSnapshots.couldNotCreateSnapshot", comment: ""), error.description), virtualMachine: virtualMachine)
        } catch {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("EditVMViewControllerSnapshots.couldNotCreateSnapshot", comment: ""), error.localizedDescription), virtualMachine: virtualMachine)
        }
    }

    func snapshotDeleted() {
        currentSnapshot = nil
        updateView()
    }

    func snapshotRestored(showAlert: Bool) {
        updateView()
        if showAlert {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.informational, message: NSLocalizedString("EditVMViewControllerSnapshots.snapshotRestoredSuccessfully", comment: ""), virtualMachine: virtualMachine)
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self)

        if let virtualMachine {
            if let snapshots = virtualMachine.snapshots {
                let snapshot = snapshots[row]
                if let cell = cell as? NSTableCellView {
                    cell.textField?.stringValue = formatTimestamp(snapshot) + " - " + (snapshot.running ? NSLocalizedString("EditVMViewControllerSnapshots.live", comment: "") : NSLocalizedString("EditVMViewControllerSnapshots.atRest", comment: ""))
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
            let message = NSLocalizedString("EditVMViewControllerSnapshots.deletionConfirmMessage", comment: "")
            let response = Utils.showPrompt(window: view.window!, style: NSAlert.Style.warning, message: message, virtualMachine: virtualMachine)
            return response.rawValue == Utils.ALERT_RESP_OK
        } else if identifier == MacMulatorConstants.RESTORE_SNAPSHOT_SEGUE {
            if let vmRunner {
                let performSegue = !vmRunner.isVMRunning() || !Utils.isPauseSupported(vmRunner.getManagedVM())
                if !performSegue, let currentSnapshot {
                    do {
                        try vmRunner.restoreVMSnapshot(snapshot: currentSnapshot, nil)
                        snapshotRestored(showAlert: false)
                    } catch let error as ValidationError {
                        Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("EditVMViewControllerSnapshots.couldNotRestoreSnapshot", comment: ""), error.description), virtualMachine: nil)
                    } catch {
                        Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("EditVMViewControllerSnapshots.couldNotRestoreSnapshot", comment: ""), error.localizedDescription), virtualMachine: nil)
                    }
                }
                return performSegue
            }
            return true
        }
        return true
    }

    override func prepare(for segue: NSStoryboardSegue, sender _: Any?) {
        if segue.identifier == MacMulatorConstants.DELETE_SNAPSHOT_SEGUE || segue.identifier == MacMulatorConstants.RESTORE_SNAPSHOT_SEGUE {
            let destinationController = segue.destinationController as! ManageSnapshotViewController
            destinationController.setSnapshot(currentSnapshot)
            destinationController.setVmRunner(vmRunner)
            destinationController.setParentController(self)
            destinationController.setOperation(segue.identifier!)
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

            snapshotTitleLabel.stringValue = (currentSnapshot.running ? NSLocalizedString("EditVMViewControllerSnapshots.liveSnapshot", comment: "") : NSLocalizedString("EditVMViewControllerSnapshots.atRestSnapshot", comment: "")) + " - " + currentSnapshot.name + formatTimestamp(currentSnapshot)
            if let screenshotPath = currentSnapshot.screenshotPath {
                snapshotScreenshotView.image = NSImage(contentsOf: NSURL.fileURL(withPath: screenshotPath))
            } else {
                snapshotScreenshotView.image = nil
            }
            snapshotDescriptionTextView.string = currentSnapshot.description
        } else {
            snapshotTitleLabel.stringValue = NSLocalizedString("EditVMViewControllerSnapshots.selectSnapshotmessage", comment: "")
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
