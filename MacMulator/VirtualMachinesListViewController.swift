//
//  VirtualMachinesListViewController.swift
//  MacMulator
//
//  Created by Vale on 28/01/21.
//

import Cocoa

class VirtualMachinesListViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
     
    @IBOutlet weak var table: NSTableView!
    
    var virtualMachines: [VirtualMachine] = [];
    var rootController: RootViewController?;
    
    func setRootController(rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    func addVirtualMachine(virtualMachine: VirtualMachine) {
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
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView;
        let selectedvm = virtualMachines[tableView.selectedRow];
        rootController!.setCurrentVirtualMachine(currentVm: selectedvm);
    }
}
