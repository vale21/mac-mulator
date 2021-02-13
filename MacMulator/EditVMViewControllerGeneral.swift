//
//  GeneralEditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewControllerGeneral: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    let supportedResolutions = ["1024 x 768", "1280 x 800", "1440 x 900", "1920 x 1080"];
    
    @IBOutlet weak var vmType: NSComboBox!
    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet weak var vmLocation: NSTextField!
    @IBOutlet var vmDescription: NSTextView!
    @IBOutlet weak var bootOrderTable: NSTableView!
    @IBOutlet weak var resolutionTable: NSTableView!
    
    var virtualMachine: VirtualMachine?;
    let accountPasteboardType = NSPasteboard.PasteboardType.string;

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
        
        vmType.selectItem(withObjectValue: vm.os);
        vmName.stringValue = vm.displayName;
        vmLocation.stringValue = vm.path;
        vmDescription.string = vm.description ?? "";
        resolutionTable.selectRowIndexes(IndexSet(integer: IndexSet.Element(getResolutionIndex(vm.displayResolution))), byExtendingSelection: false);
        bootOrderTable.reloadData();
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bootOrderTable.registerForDraggedTypes([accountPasteboardType]);
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
            return virtualMachine?.bootOrder.count ?? 0;
        }
        if tableView == resolutionTable {
            return supportedResolutions.count;
        }
        return 0;
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self);
        if tableView == bootOrderTable {
            cell?.addSubview(NSTextField(labelWithString: virtualMachine?.bootOrder[row] ?? ""));
        }
        if tableView == resolutionTable {
            cell?.addSubview(NSTextField(labelWithString: supportedResolutions[row]));
        }
        return cell;
    }
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let opt = virtualMachine?.bootOrder[row] else { return nil };
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(opt, forType: accountPasteboardType)
        return pasteboardItem
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
            let item: NSPasteboardItem = info.draggingPasteboard.pasteboardItems?.first,
            let value: String = item.string(forType: accountPasteboardType),
            let option: String = virtualMachine?.bootOrder.first(where: { $0 == value }),
            let originalRow: Int = virtualMachine?.bootOrder.firstIndex(of: option)
        else { return false }
        
        var newRow:Int = row;
        // When you drag an item downwards, the "new row" index is actually --1. Remember dragging operation is `.above`.
        if originalRow < newRow {
            newRow = row - 1
        }
        
        // Animate the rows
        tableView.beginUpdates()
        tableView.moveRow(at: originalRow, to: newRow)
        tableView.endUpdates()
        
        if let virtualMachine = self.virtualMachine {
            let originalValue = virtualMachine.bootOrder[originalRow];
            let newValue = virtualMachine.bootOrder[newRow];
            virtualMachine.bootOrder[newRow] = originalValue;
            virtualMachine.bootOrder[originalRow] = newValue;
        }
        
        return true
    }
}


