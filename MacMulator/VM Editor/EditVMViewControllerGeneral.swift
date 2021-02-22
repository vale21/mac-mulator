//
//  GeneralEditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewControllerGeneral: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSComboBoxDataSource, NSComboBoxDelegate, NSTextFieldDelegate, NSTextViewDelegate {

    let supportedResolutions: [String:String] = [
        QemuConstants.RES_640_480: "640 x 480",
        QemuConstants.RES_800_600: "800 x 600",
        QemuConstants.RES_1024_768: "1024 x 768",
        QemuConstants.RES_1280_1024: "1280 x 1024",
        QemuConstants.RES_1600_1200: "1600 x 1200",
        QemuConstants.RES_1024_600: "1024 x 600",
        QemuConstants.RES_1280_800: "1280 x 800",
        QemuConstants.RES_1440_900: "1440 x 900",
        QemuConstants.RES_1680_1050: "1680 x 1050",
        QemuConstants.RES_1920_1200: "1920 x 1200",
        QemuConstants.RES_1280_720: "HD 720p (1280 x 720)",
        QemuConstants.RES_1920_1080: "HD 1080p (1920 x 1080)",
        QemuConstants.RES_2048_1152: "2K (2048 x 1152)",
        QemuConstants.RES_2560_1440: "QHD (2560 x 1440)",
        QemuConstants.RES_3840_2160: "UHD (3840 x 2160)",
        QemuConstants.RES_4096_2160: "4K (4096 x 2160)",
        QemuConstants.RES_5120_2280: "5K (5120 x 2280",
        QemuConstants.RES_6016_3384: "6K (6016 x 3384)"
    ];
    
    let supportedVMTypes: [String] = [
        QemuConstants.OS_MAC,
        QemuConstants.OS_WIN,
        QemuConstants.OS_LINUX
    ]
    
    
    @IBOutlet weak var vmType: NSComboBox!
    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet var vmDescription: NSTextView!
    @IBOutlet weak var bootOrderTable: NSTableView!
    @IBOutlet weak var resolutionTable: NSTableView!
    
    var virtualMachine: VirtualMachine?;
    let accountPasteboardType = NSPasteboard.PasteboardType.string;
        
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
        updateView();
    }
    
    override func viewWillAppear() {
        updateView();
    }
    
    func updateView() {
        if let virtualMachine = self.virtualMachine {
            vmType.selectItem(at: supportedVMTypes.firstIndex(of: virtualMachine.os)!);
            vmName.stringValue = virtualMachine.displayName;
            vmDescription.string = virtualMachine.description ?? "";
            let rowIndex: Array<String>.Index = QemuConstants.ALL_RESOLUTIONS.firstIndex(of: virtualMachine.displayResolution)!
            resolutionTable.selectRowIndexes(IndexSet(integer: IndexSet.Element(rowIndex)), byExtendingSelection: false);
            resolutionTable.scrollRowToVisible((-1 * (rowIndex.distance(to: 0))) + 2);
            bootOrderTable.reloadData();
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bootOrderTable.registerForDraggedTypes([accountPasteboardType]);
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
            cell?.addSubview(NSTextField(labelWithString: supportedResolutions[QemuConstants.ALL_RESOLUTIONS[row]]!));
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
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return supportedVMTypes.count;
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return supportedVMTypes[index];
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        virtualMachine?.os = supportedVMTypes[vmType.indexOfSelectedItem];
    }
    
    func controlTextDidChange(_ notification: Notification) {
        if ((notification.object as! NSTextField) == vmName) {
            virtualMachine?.displayName = vmName.stringValue;
        }
    }
    
    func textDidChange(_ notification: Notification) {
        if ((notification.object as? NSTextView) == vmDescription) {
            virtualMachine?.description = vmDescription.string;
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if ((notification.object as! NSTableView) == resolutionTable) {
            virtualMachine?.displayResolution = QemuConstants.ALL_RESOLUTIONS[resolutionTable.selectedRow];
        }
    }
}


