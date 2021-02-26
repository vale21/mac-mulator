//
//  CreateDiskFileViewController.swift
//  MacMulator
//
//  Created by Vale on 23/02/21.
//

import Cocoa

class CreateDiskFileViewController: NSViewController {
    
    @IBOutlet weak var progressBar: NSProgressIndicator!
    
    var virtualDrive: VirtualDrive?
    var parentController: NewDiskViewController?;
    
    func setVirtualDrive(_ virtualDrive: VirtualDrive) {
        self.virtualDrive = virtualDrive;
    }
    
    func setparentController(_ parentController: NewDiskViewController) {
        self.parentController = parentController;
    }
    
    override func viewDidAppear() {
        progressBar.startAnimation(self);
        
        if let virtualDrive = self.virtualDrive {
            var complete = false;
            
            let dispatchQueue = DispatchQueue(label: "New Disk Thread", qos: DispatchQoS.background);
            dispatchQueue.async {
                if (self.parentController?.mode == NewDiskViewController.Mode.ADD) {
                    QemuUtils.createDiskImage(path: virtualDrive.path, virtualDrive: virtualDrive);
                    virtualDrive.path = Utils.escape(virtualDrive.path + "/" + virtualDrive.name + QemuUtils.getExtension(virtualDrive.format));
                } else {
                    QemuUtils.updateDiskImage(virtualDrive);
                }
                complete = true;
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
