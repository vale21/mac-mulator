//
//  CreateDiskFileViewController.swift
//  MacMulator
//
//  Created by Vale on 23/02/21.
//

import Cocoa

class CreateDiskFileViewController: NSViewController {
    
    @IBOutlet weak var progressBar: NSProgressIndicator!
    
    var oldVirtualDrive: VirtualDrive?
    var newVirtualDrive: VirtualDrive?
    var parentController: NewDiskViewController?;
    
    func setOldVirtualDrive(_ virtualDrive: VirtualDrive?) {
        self.oldVirtualDrive = virtualDrive;
    }
    
    func setNewVirtualDrive(_ virtualDrive: VirtualDrive?) {
        self.newVirtualDrive = virtualDrive;
    }
    
    func setparentController(_ parentController: NewDiskViewController) {
        self.parentController = parentController;
    }
    
    override func viewDidAppear() {
        progressBar.startAnimation(self);
        
        if let newVirtualDrive = self.newVirtualDrive {
            var complete = false;
            
            let dispatchQueue = DispatchQueue(label: "New Disk Thread", qos: DispatchQoS.background);
            dispatchQueue.async {
                if (self.parentController?.mode == NewDiskViewController.Mode.ADD) {
                    QemuUtils.createDiskImage(path: newVirtualDrive.path, virtualDrive: newVirtualDrive, uponCompletion: {
                        complete = true;
                    });
                    newVirtualDrive.path = Utils.escape(newVirtualDrive.path + "/" + newVirtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION);
                } else {
                    QemuUtils.updateDiskImage(oldVirtualDrive: self.oldVirtualDrive!, newVirtualDrive: newVirtualDrive, uponCompletion: {
                        complete = true;
                    });
                }
            }
            
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
            
                guard !complete else {
                    timer.invalidate();
                    self.progressBar.stopAnimation(self);
                    self.dismiss(self);
                    
                    self.parentController!.diskCreated();
                    return;
                }
            })
        }
    }
    
}
