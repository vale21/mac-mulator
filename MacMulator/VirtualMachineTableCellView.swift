//
//  VirtualMachineTableCellView.swift
//  MacMulator
//
//  Created by Vale on 28/01/21.
//

import Cocoa

class VirtualMachineTableCellView: NSTableCellView {

    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet weak var vmIcon: NSImageView!
    @IBOutlet weak var runningSpinner: NSProgressIndicator!
    
    var virtualMachine: VirtualMachine?
    var rootController: RootViewController?
    
    func setVirtualMachine(virtualMachine: VirtualMachine) {
        self.virtualMachine = virtualMachine
        self.refresh()
    }
    
    func setRunning(_ running: Bool) {
        if running {
            runningSpinner.isHidden = false
            runningSpinner.startAnimation(self)
            vmIcon.isHidden = true
        } else {
            runningSpinner.isHidden = true
            runningSpinner.stopAnimation(self)
            vmIcon.isHidden = false
        }
        self.refresh()
    }
    
    func refresh() {
        if let virtualMachine = virtualMachine {
            vmName.stringValue = virtualMachine.displayName
            
            if let rootController = rootController {
                if rootController.isVMPaused(virtualMachine) {
                    let background = NSImage.init(named: NSImage.Name(Utils.getIconForSubType(virtualMachine.os, virtualMachine.subtype) + ".small"))
                    if let background = background {
                        let overlay = NSImage.init(named: NSImage.Name("pause.overlay"))
                        if let overlay = overlay {
                            
                            let newImage = NSImage(size: background.size)
                            newImage.lockFocus()
                            var newImageRect: CGRect = .zero
                            newImageRect.size = newImage.size
                            background.draw(in: newImageRect)
                            overlay.draw(in: newImageRect)
                            newImage.unlockFocus()
                            
                            vmIcon.image = newImage
                        }
                    }
                } else {
                    vmIcon.image = NSImage.init(named: NSImage.Name(Utils.getIconForSubType(virtualMachine.os, virtualMachine.subtype) + ".small"))
                }
            }
        }
    }
}
