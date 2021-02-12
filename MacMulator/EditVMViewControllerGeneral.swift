//
//  GeneralEditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewControllerGeneral: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    let supportedResolutions = ["1024 x 768", "1280 x 800", "1440 x 900", "1920 x 1080"];
    let bootOrder = ["CD/DVD", "Hard Disk", "Network"];
    
    @IBOutlet weak var vmType: NSComboBox!
    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet weak var vmLocation: NSTextField!
    @IBOutlet var vmDescription: NSTextView!
    @IBOutlet weak var bootOrderTable: NSTableView!
    @IBOutlet weak var resolutionTable: NSTableView!
    
    var virtualMachine: VirtualMachine?
    
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
        
        vmType.selectItem(at: QemuConstants.getOSIndex(vm.os));
        vmName.stringValue = vm.displayName;
        vmLocation.stringValue = vm.path;
        vmDescription.string = vm.description ?? "";
        resolutionTable.selectRowIndexes(IndexSet(integer: IndexSet.Element(getResolutionIndex(vm.displayResolution))), byExtendingSelection: false);
    }
    
    func getResolutionIndex(_ res:String) -> Int {
        var i = 0;
        for var resolution in supportedResolutions {
            resolution = resolution.replacingOccurrences(of: " ", with: "");
            if (res.hasPrefix(resolution)) {
                return i;
            }
            i += 1;
        }
        return -1;
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == bootOrderTable {
            return bootOrder.count;
        }
        if tableView == resolutionTable {
            return supportedResolutions.count;
        }
        return 0;
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self);
        if tableView == bootOrderTable {
            cell?.addSubview(NSTextField(labelWithString: bootOrder[row]));
        }
        if tableView == resolutionTable {
            cell?.addSubview(NSTextField(labelWithString: supportedResolutions[row]));
        }
        return cell;
    }
}


