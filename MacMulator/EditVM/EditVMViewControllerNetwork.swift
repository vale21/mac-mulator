//
//  EditVMViewControllerNetwork.swift
//  MacMulator
//
//  Created by Vale on 03/06/22.
//

import Cocoa

class EditVMViewControllerNetwork : NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var networkAdapterComboBox: NSComboBox!
    @IBOutlet weak var mappingsTableView: NSTableView!
    
    var virtualMachine: VirtualMachine?;
 
    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm;
        updateView();
    }
    
    override func viewWillAppear() {
        updateView();
    }
    
    func updateView() {
        if let virtualMachine = self.virtualMachine {
            networkAdapterComboBox.reloadData();
            mappingsTableView.reloadData();
        }
    }
}
