//
//  GeneralEditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewControllerGeneral: NSViewController {
    
    @IBOutlet weak var vmType: NSComboBox!
    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet weak var vmLocation: NSTextField!
    @IBOutlet var vmDescription: NSTextView!
    @IBOutlet weak var bootOrderTable: NSTableView!
    @IBOutlet weak var resolutionTable: NSTableView!
    
    var virtualMachine: VirtualMachine?
    
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
        
        vmName.stringValue = vm.displayName;
    }
}


