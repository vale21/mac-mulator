//
//  DrivesTableIconCell.swift
//  MacMulator
//
//  Created by Vale on 22/02/21.
//

import Cocoa

class MappingsNameCell: NSTableCellView {
    @IBOutlet weak var label: NSTextField!
}

class VirtualMachinePortCell: NSTableCellView {
    @IBOutlet weak var label: NSTextField!
    
    override func viewWillDraw() {
        let portNumberFormatter = NumberFormatter()
        portNumberFormatter.hasThousandSeparators = false
        
        label.formatter = portNumberFormatter
    }
}

class HostMacPortCell: NSTableCellView {
    @IBOutlet weak var label: NSTextField!
    
    override func viewWillDraw() {
        let portNumberFormatter = NumberFormatter()
        portNumberFormatter.hasThousandSeparators = false
        
        label.formatter = portNumberFormatter
    }
}
