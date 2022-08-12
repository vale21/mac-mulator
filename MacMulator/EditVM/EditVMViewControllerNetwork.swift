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
        if let virtualMachine = virtualMachine {
            networkAdapterComboBox.reloadData();
            networkAdapterComboBox.selectItem(at: QemuConstants.ALL_NETWORK_ADAPTERS.firstIndex(of: virtualMachine.networkDevice ?? Utils.getNetworkForSubType(virtualMachine.os, virtualMachine.subtype)) ?? -1);
            
            mappingsTableView.reloadData();
        }
    }
    
    func reloadPortMappings() {
        self.mappingsTableView.reloadData();
    }
    
    func addPortmapping(_ portMapping: PortMapping) {
        if let virtualMachine = self.virtualMachine {
            virtualMachine.portMappings?.append(portMapping)
            reloadPortMappings()
        }
    }
    
    @IBAction func deletePortmapping(_ sender: Any) {
        if let virtualMachine = self.virtualMachine {
            let row = mappingsTableView.row(for: sender as! NSView)
            virtualMachine.portMappings?.remove(at: row)
            reloadPortMappings()
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        let destinationController = segue.destinationController as! NewPortMappingViewController;
        destinationController.setParentController(self);
        if let virtualMachine = self.virtualMachine {
            if let portMappings = virtualMachine.portMappings {
                if (segue.identifier == MacMulatorConstants.NEW_PORT_MAPPING_SEGUE) {
                    destinationController.setMode(NewPortMappingViewController.Mode.ADD);
                }
                if (segue.identifier == MacMulatorConstants.EDIT_PORT_MAPPING_SEGUE) {
                    destinationController.setMode(NewPortMappingViewController.Mode.EDIT);
                    let driveTableRow: Int = mappingsTableView.row(for: sender as! NSView)
                    destinationController.setPortmapping(portMappings[driveTableRow])
                }
            }
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return virtualMachine?.portMappings?.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self);
        
        if let virtualMachine = self.virtualMachine {
            if let portMappings = virtualMachine.portMappings {
                let mapping = portMappings[row]
                
                if tableColumn?.identifier.rawValue == "Name" {
                    let cellView = cell as! MappingsNameCell
                    cellView.label.stringValue = mapping.name
                }
                
                if tableColumn?.identifier.rawValue == "VM" {
                    let cellView = cell as! VirtualMachinePortCell
                    cellView.label.intValue = mapping.vmPort
                }
                
                if tableColumn?.identifier.rawValue == "Host" {
                    let cellView = cell as! HostMacPortCell
                    cellView.label.intValue = mapping.hostPort
                }
            }
        }
        
        return cell;
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30.0;
    }
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return QemuConstants.ALL_NETWORK_ADAPTERS_DESC.count
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if (comboBox == networkAdapterComboBox) {
            return index >= 0 ? QemuConstants.ALL_NETWORK_ADAPTERS_DESC[QemuConstants.ALL_NETWORK_ADAPTERS[index]] : "";
        }
        return (index + 1);
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        if (notification.object as! NSComboBox) == networkAdapterComboBox {
            if let virtualMachine = self.virtualMachine {
                virtualMachine.networkDevice = QemuConstants.ALL_NETWORK_ADAPTERS[networkAdapterComboBox.indexOfSelectedItem];
            }
        }
    }
}
