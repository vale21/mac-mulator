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
    
    var virtualMachines: [VirtualMachine] = [];
    var rootController: RootViewController?;
    
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    func addVirtualMachine(_ virtualMachine: VirtualMachine) {
        virtualMachines.append(virtualMachine);
        self.table.reloadData();
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return virtualMachines.count;
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 55.0;
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! VirtualMachineTableCellView;
        cell.setVirtualMachine(virtualMachine: virtualMachines[row]);
        return cell;
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        return [
            NSTableViewRowAction(style: NSTableViewRowAction.Style.destructive, title: "Delete", handler: { action, index in self.deleteVirtualMachine(index)}),
            NSTableViewRowAction(style: NSTableViewRowAction.Style.regular, title: "Edit", handler: { action, index in self.editVirtualMachine(index)}),
        ];
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView;
        let selectedvm = virtualMachines[tableView.selectedRow];
        rootController!.setCurrentVirtualMachine(selectedvm);
    }
    
    override func viewDidLoad() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Edit", action: #selector(tableViewEditItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(tableViewDeleteItemClicked(_:)), keyEquivalent: ""))
        table.menu = menu
    }
    
    @objc func tableViewEditItemClicked(_ sender: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        editVirtualMachine(table.clickedRow);
    }
    
    @objc func tableViewDeleteItemClicked(_ sender: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        deleteVirtualMachine(table.clickedRow);
        
    }
    
    func editVirtualMachine(_ index: Int) {
        let item = virtualMachines[index];
        print("Edit " + item.displayName);
    }
        
    func deleteVirtualMachine(_ index: Int) {
        let removed = virtualMachines.remove(at: index);
        table.reloadData();
        
        rootController?.deleteVirtualMachine(removed);
    }
}
