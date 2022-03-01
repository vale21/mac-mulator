//
//  VirtualMachinesListViewController.swift
//  MacMulator
//
//  Created by Vale on 28/01/21.
//

import Cocoa

class VirtualMachinesListViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
     
    @IBOutlet weak var table: NSTableView!
    @IBOutlet weak var rightClickmenu: NSMenu!
    
    var rootController: RootViewController?;
    
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return rootController?.getVirtualMachinesCount() ?? 0;
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 55.0;
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! VirtualMachineTableCellView;
        if let rootController = self.rootController {
            let vm: VirtualMachine = rootController.getVirtualMachineAt(row);
            cell.setVirtualMachine(virtualMachine: vm);
            cell.setRunning(rootController.isVMRunning(vm));
        }
        return cell;
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        return [
            NSTableViewRowAction(style: NSTableViewRowAction.Style.destructive, title: "Delete", handler: { action, index in self.deleteVirtualMachine(index)}),
            NSTableViewRowAction(style: NSTableViewRowAction.Style.regular, title: "Edit", handler: { action, index in self.editVirtualMachine(index)}),
        ];
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let rootController = self.rootController {
            let tableView = notification.object as! NSTableView;
            if tableView.selectedRow >= 0 {
                let selectedvm = rootController.getVirtualMachineAt(tableView.selectedRow);
                if selectedvm != rootController.currentVm {
                    rootController.setCurrentVirtualMachine(selectedvm);
                }
            }
        }
    }
    
    let accountPasteboardType = NSPasteboard.PasteboardType(rawValue: "virtual.machine");
    
    override func viewDidLoad() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Edit", action: #selector(tableViewEditItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(tableViewDeleteItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator());
        menu.addItem(NSMenuItem(title: "Show in Finder", action: #selector(tableViewShowInFinderItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Clone", action: #selector(tableViewCloneItemClicked(_:)), keyEquivalent: ""))
        table.menu = menu
        table.registerForDraggedTypes([accountPasteboardType]);
        table.allowsMultipleSelection = false;
    }
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let virtualMachine = rootController?.getVirtualMachineAt(row);
        if let vm = virtualMachine {
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(vm.displayName, forType: accountPasteboardType)
            return pasteboardItem
        }
        return nil;
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        } else {
            return []
        }
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
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
    
    @objc func tableViewEditItemClicked(_ sender: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        editVirtualMachine(table.clickedRow);
    }
    
    @objc func tableViewDeleteItemClicked(_ sender: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        deleteVirtualMachine(table.clickedRow);
    }
    
    @objc func tableViewShowInFinderItemClicked(_ sender: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        showVirtualMachineInFinder(table.clickedRow);
    }
    
    @objc func tableViewCloneItemClicked(_ sender: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        cloneVirtualMachine(table.clickedRow);
    }

    func editVirtualMachine(_ index: Int) {
        if let rootController = self.rootController {
            let item = rootController.getVirtualMachineAt(index);
            self.view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.EDIT_VM_SEGUE, sender: item);
        }
    }
        
    func deleteVirtualMachine(_ index: Int) {
        if let rootController = self.rootController {
            table.removeRows(at: IndexSet(integer: IndexSet.Element(index)), withAnimation: NSTableView.AnimationOptions.slideUp);
            rootController.removeVirtualMachineAt(index);
        }
    }
    
    func showVirtualMachineInFinder(_ index: Int) {
        if let rootController = self.rootController {
            let vm = rootController.getVirtualMachineAt(index);
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: vm.path, isDirectory: false)]);
        }
    }
    
    func cloneVirtualMachine(_ index: Int) {
        rootController?.cloneVirtualMachineAt(index);
    }
    
    func selectElement(_ index: Int) {
        table.selectRowIndexes(IndexSet(integer: IndexSet.Element(index)), byExtendingSelection: false);
    }
    
    func refreshList() {
        self.table.reloadData();
    }
    
    func setRunning(_ index: Int, _ running: Bool) {
        let view = table.view(atColumn: 0, row: index, makeIfNecessary: false) as? VirtualMachineTableCellView;
        if let cellView = view {
            cellView.setRunning(running);
        }
    }
}
