//
//  VirtualMachinesListViewController.swift
//  MacMulator
//
//  Created by Vale on 28/01/21.
//

import Cocoa

class VirtualMachinesListViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate {
    @IBOutlet var table: NSTableView!

    var rootController: RootViewController?

    func setRootController(_ rootController: RootViewController) {
        self.rootController = rootController
    }

    func numberOfRows(in _: NSTableView) -> Int {
        rootController?.getVirtualMachinesCount() ?? 0
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        55.0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! VirtualMachineTableCellView
        if let rootController {
            cell.setRootController(rootController)

            let vm: VirtualMachine = rootController.getVirtualMachineAt(row)
            cell.setVirtualMachine(virtualMachine: vm)
        }
        return cell
    }

    func tableView(_: NSTableView, rowActionsForRow _: Int, edge _: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        [
            NSTableViewRowAction(style: NSTableViewRowAction.Style.destructive, title: NSLocalizedString("VirtualMachineListViewController.delete", comment: ""), handler: { _, index in self.deleteVirtualMachine(index) }),
            NSTableViewRowAction(style: NSTableViewRowAction.Style.regular, title: NSLocalizedString("VirtualMachineListViewController.edit", comment: ""), handler: { _, index in self.editVirtualMachine(index) }),
        ]
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if let rootController {
            let tableView = notification.object as! NSTableView
            if tableView.selectedRow >= 0 {
                let selectedvm = rootController.getVirtualMachineAt(tableView.selectedRow)
                if selectedvm != rootController.currentVm {
                    rootController.setCurrentVirtualMachine(selectedvm)
                }
            }
        }
    }

    let accountPasteboardType = NSPasteboard.PasteboardType(rawValue: "virtual.machine")

    override func viewDidLoad() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        menu.addItem(NSMenuItem(title: NSLocalizedString("VirtualMachineListViewController.start", comment: ""), action: #selector(tableViewStartItemClicked(_:)), keyEquivalent: ""))
        #if arch(arm64)
            menu.addItem(NSMenuItem(title: NSLocalizedString("VirtualMachineListViewController.startInRecovery", comment: ""), action: #selector(tableViewStartInRecoveryItemClicked(_:)), keyEquivalent: ""))
        #endif
        menu.addItem(NSMenuItem(title: NSLocalizedString("VirtualMachineListViewController.stop", comment: ""), action: #selector(tableViewStopItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: NSLocalizedString("VirtualMachineListViewController.pause", comment: ""), action: #selector(tableViewPauseItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("VirtualMachineListViewController.edit", comment: ""), action: #selector(tableViewEditItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: NSLocalizedString("VirtualMachineListViewController.delete", comment: ""), action: #selector(tableViewDeleteItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("VirtualMachineListViewController.showInFinder", comment: ""), action: #selector(tableViewShowInFinderItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: NSLocalizedString("VirtualMachineListViewController.clone", comment: ""), action: #selector(tableViewCloneItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: NSLocalizedString("VirtualMachineListViewController.convertToTemplate", comment: ""), action: #selector(tableViewConvertToTemplateItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: NSLocalizedString("VirtualMachineListViewController.convertToFullClone", comment: ""), action: #selector(tableViewConvertToFullCloneItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("VirtualMachineListViewController.createSnapshot", comment: ""), action: #selector(tableViewTakeSnapshotItemClicked(_:)), keyEquivalent: ""))
        table.menu = menu
        table.registerForDraggedTypes([accountPasteboardType])
        table.allowsMultipleSelection = false

        NotificationCenter.default.addObserver(self, selector: #selector(vmPauseStateChanged(_:)), name: MacMulatorConstants.VM_PAUSE_STATE_CHANGED_NOTIFICATION, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let returnKeyMonitor {
            NSEvent.removeMonitor(returnKeyMonitor)
        }
    }

    private var returnKeyMonitor: Any?

    override func viewDidAppear() {
        super.viewDidAppear()
        guard returnKeyMonitor == nil else { return }
        // Pressing Return on the selected VM renames it, as in the Finder.
        returnKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = view.window, event.window === window, window.firstResponder === table,
                  event.keyCode == 36 || event.keyCode == 76, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
            else {
                return event
            }
            beginRenamingSelectedVirtualMachine()
            return nil
        }
    }

    private func beginRenamingSelectedVirtualMachine() {
        let row = table.selectedRow
        guard row >= 0, let rootController, let cell = table.view(atColumn: 0, row: row, makeIfNecessary: false) as? VirtualMachineTableCellView else { return }
        let vm = rootController.getVirtualMachineAt(row)
        // The running VMs are tracked by name, so they can't be renamed.
        guard !rootController.isVMRunning(vm) else {
            NSSound.beep()
            return
        }
        cell.beginRenaming { [weak self] newName in
            self?.renameVirtualMachine(vm, to: newName)
        }
    }

    private func renameVirtualMachine(_ vm: VirtualMachine, to newName: String) {
        guard let rootController else { return }
        if rootController.virtualMachines.contains(where: { $0 !== vm && $0.displayName == newName }) {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("VirtualMachineListViewController.renameDuplicate", comment: ""), newName), virtualMachine: vm)
            return
        }
        vm.displayName = newName
        vm.writeToPlist()
        // The folder of the VM follows its name.
        rootController.renameVMFolderToMatchName(vm)
        rootController.refreshViewForVM(vm)
        if let index = rootController.virtualMachines.firstIndex(where: { $0 === vm }) {
            selectElement(index)
        }
        view.window?.makeFirstResponder(table)
    }

    func menuWillOpen(_ menu: NSMenu) {
        let row = table.clickedRow
        if let rootController {
            let vm = rootController.getVirtualMachineAt(row)
            if #unavailable(macOS 13.0,) {
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.convertToTemplate", comment: ""))?.isHidden = true
            } else {
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.convertToTemplate", comment: ""))?.isEnabled = Utils.isTemplateConversionSupported(vm)
            }

            // A paused VM can be cloned, a running one cannot.
            menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.clone", comment: ""))?.isEnabled = !rootController.isVMRunning(vm)

            if let fullCloneItem = menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.convertToFullClone", comment: "")) {
                fullCloneItem.isHidden = !vm.hasLinkedDrives || !Utils.isFullCloneConversionSupported(vm)
                fullCloneItem.isEnabled = !rootController.isVMRunning(vm)
            }

            if Utils.isVMTemplate(vm) {
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.start", comment: ""))?.isEnabled = false
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.startInRecovery", comment: ""))?.isEnabled = false
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.stop", comment: ""))?.isEnabled = false
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.pause", comment: ""))?.isEnabled = false
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.createSnapshot", comment: ""))?.isEnabled = false
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.convertToTemplate", comment: ""))?.isEnabled = false
            } else if rootController.isVMRunning(vm) {
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.start", comment: ""))?.isEnabled = false
                #if arch(arm64)
                    menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.startInRecovery", comment: ""))?.isEnabled = false
                #endif
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.stop", comment: ""))?.isEnabled = true
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.pause", comment: ""))?.isEnabled = Utils.isPauseSupported(vm)
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.convertToTemplate", comment: ""))?.isEnabled = false
            } else {
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.start", comment: ""))?.isEnabled = Utils.isVMAvailable(vm)
                #if arch(arm64)
                    menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.startInRecovery", comment: ""))?.isEnabled = Utils.isFullFeaturedMacOSVM(vm) && !rootController.isVMPaused(vm)
                #endif
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.stop", comment: ""))?.isEnabled = false
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.pause", comment: ""))?.isEnabled = false
                // A paused VM has to be stopped before becoming a template.
                menu.item(withTitle: NSLocalizedString("VirtualMachineListViewController.convertToTemplate", comment: ""))?.isEnabled = !rootController.isVMPaused(vm) && Utils.isTemplateConversionSupported(vm)
            }
        }
    }

    func tableView(_: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let virtualMachine = rootController?.getVirtualMachineAt(row)
        if let vm = virtualMachine {
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(vm.displayName, forType: accountPasteboardType)
            return pasteboardItem
        }
        return nil
    }

    func tableView(_: NSTableView, validateDrop _: NSDraggingInfo, proposedRow _: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            .move
        } else {
            []
        }
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation _: NSTableView.DropOperation) -> Bool {
        guard
            let item = info.draggingPasteboard.pasteboardItems?.first,
            let theString = item.string(forType: accountPasteboardType),
            let vm = rootController?.getVirtualMachine(name: theString),
            let originalRow = rootController?.getIndex(of: vm)
        else { return false }

        var newRow = row
        // When you drag an item downwards, the "new row" index is actually --1. Remember dragging operation is `.above`.
        if originalRow < newRow {
            newRow = row - 1
        }

        // Animate the rows
        tableView.beginUpdates()
        tableView.moveRow(at: originalRow, to: newRow)
        tableView.endUpdates()

        // Persist the ordering by saving your data model
        rootController?.moveVm(at: originalRow, to: newRow)

        return true
    }

    @objc func tableViewEditItemClicked(_: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        editVirtualMachine(table.clickedRow)
    }

    @objc func tableViewDeleteItemClicked(_: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        deleteVirtualMachine(table.clickedRow)
    }

    @objc func tableViewShowInFinderItemClicked(_: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        showVirtualMachineInFinder(table.clickedRow)
    }

    @objc func tableViewCloneItemClicked(_: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        cloneVirtualMachine(table.clickedRow)
    }

    @objc func tableViewConvertToFullCloneItemClicked(_: AnyObject) {
        if table.clickedRow >= 0 {
            rootController?.convertToFullCloneAt(table.clickedRow)
        }
    }

    @objc func tableViewConvertToTemplateItemClicked(_: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        if #available(macOS 13.0, *) {
            convertVirtualMachineToTemplate(table.clickedRow)
        }
    }

    @objc func tableViewTakeSnapshotItemClicked(_: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        createVMSnapshot(table.clickedRow)
    }

    @objc func tableViewStartItemClicked(_: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        startVirtualMachine(table.clickedRow)
    }

    @objc func tableViewStartInRecoveryItemClicked(_: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        startVirtualMachineInRecovery(table.clickedRow)
    }

    @objc func tableViewStopItemClicked(_: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        stopVirtualMachine(table.clickedRow)
    }

    @objc func tableViewPauseItemClicked(_: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        pauseVirtualMachine(table.clickedRow)
    }

    func editVirtualMachine(_ index: Int) {
        if let rootController {
            let item = rootController.getVirtualMachineAt(index)
            view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.EDIT_VM_SEGUE, sender: [nil, item])
        }
    }

    func deleteVirtualMachine(_ index: Int) {
        if let rootController {
            guard rootController.canDelete(rootController.getVirtualMachineAt(index)) else { return }
            if rootController.isVMRunning(rootController.getVirtualMachineAt(index)) {
                let response = Utils.showPrompt(window: rootController.view.window!, style: NSAlert.Style.warning, message: NSLocalizedString("VirtualMachineListViewController.runningVM", comment: ""), virtualMachine: rootController.getVirtualMachineAt(index))
                if response.rawValue == Utils.ALERT_RESP_OK {
                    table.removeRows(at: IndexSet(integer: IndexSet.Element(index)), withAnimation: NSTableView.AnimationOptions.slideUp)
                    _ = rootController.removeVirtualMachineAt(index)
                }
            } else {
                table.removeRows(at: IndexSet(integer: IndexSet.Element(index)), withAnimation: NSTableView.AnimationOptions.slideUp)
                _ = rootController.removeVirtualMachineAt(index)
            }
        }
    }

    func showVirtualMachineInFinder(_ index: Int) {
        if let rootController {
            let vm = rootController.getVirtualMachineAt(index)
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: vm.path, isDirectory: false)])
        }
    }

    func startVirtualMachine(_ index: Int) {
        if let rootController {
            _ = rootController.getVirtualMachineAt(index)
            table.selectRowIndexes(IndexSet(integer: IndexSet.Element(index)), byExtendingSelection: false)
            rootController.startVMMenuBarClicked(self)
        }
    }

    func startVirtualMachineInRecovery(_ index: Int) {
        if let rootController {
            _ = rootController.getVirtualMachineAt(index)
            table.selectRowIndexes(IndexSet(integer: IndexSet.Element(index)), byExtendingSelection: false)
            rootController.startVMInRecoveryMenuBarClicked(self)
        }
    }

    func stopVirtualMachine(_ index: Int) {
        if let rootController {
            _ = rootController.getVirtualMachineAt(index)
            table.selectRowIndexes(IndexSet(integer: IndexSet.Element(index)), byExtendingSelection: false)
            rootController.stopVMMenubarClicked(self)
        }
    }

    func pauseVirtualMachine(_ index: Int) {
        if let rootController {
            _ = rootController.getVirtualMachineAt(index)
            table.selectRowIndexes(IndexSet(integer: IndexSet.Element(index)), byExtendingSelection: false)
            rootController.pauseVMMenuBarClicked(self)
        }
    }

    func cloneVirtualMachine(_ index: Int) {
        rootController?.cloneVirtualMachineAt(index)
    }

    @available(macOS 13.0, *)
    func convertVirtualMachineToTemplate(_ index: Int) {
        rootController?.convertVirtualMachineToTemplateAt(index)
    }

    func createVMSnapshot(_ index: Int) {
        if let rootController {
            _ = rootController.getVirtualMachineAt(index)
            table.selectRowIndexes(IndexSet(integer: IndexSet.Element(index)), byExtendingSelection: false)
            rootController.createVMSnapshot(sender: self)
        }
    }

    func selectElement(_ index: Int) {
        table.selectRowIndexes(IndexSet(integer: IndexSet.Element(index)), byExtendingSelection: false)
    }

    func refreshList() {
        table.reloadData()
    }

    func setState(_ index: Int, _ state: VirtualMachineTableCellView.CellState) {
        let view = table.view(atColumn: 0, row: index, makeIfNecessary: false) as? VirtualMachineTableCellView
        if let cellView = view {
            cellView.setState(state)
        }
    }

    func setState(_ index: Int, _ vm: VirtualMachine) {
        let view = table.view(atColumn: 0, row: index, makeIfNecessary: false) as? VirtualMachineTableCellView
        if let cellView = view, let rootController {
            cellView.setState(VirtualMachineTableCellView.computeVMState(vm, rootController))
        }
    }

    @objc private func vmPauseStateChanged(_ notification: Notification) {
        let changedVM = notification.object as? VirtualMachine
        if changedVM != rootController?.currentVm || rootController?.isCurrentVMRunning() == true {
            return
        }

        DispatchQueue.main.async {
            if let changedVM {
                self.rootController?.unsetRunningVM(changedVM)
            }
        }
    }
}
