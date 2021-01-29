//
//  NewVMViewController.swift
//  MacMulator
//
//  Created by Vale on 29/01/21.
//

import Cocoa

class NewVMViewController: NSViewController {
    
    let defaultMemorySize:Int32 =  512;
    let defaultDriveSize:Int32 = 20;
    
    var memorySize:Int32 = 512;
    var driveSize:Int32 = 20;
    var vmLocation: String = "/Users/Vale";
    
    @IBOutlet weak var name: NSTextField!
    @IBOutlet weak var path: NSTextField!
    
    @IBOutlet weak var memorySizeField: NSTextField!
    @IBOutlet weak var memorySizeSlider: NSSlider!
    @IBOutlet weak var memorySizeStepper: NSStepper!
    
    @IBOutlet weak var diskImage: NSTextField!
    
    @IBOutlet weak var driveSizeField: NSTextField!
    @IBOutlet weak var driveSizeSlider: NSSlider!
    @IBOutlet weak var driveSizeStepper: NSStepper!
    
    override func viewDidLoad() {
        memorySizeField.stringValue = String(defaultMemorySize);
        memorySizeSlider.intValue = defaultMemorySize;
        memorySizeStepper.intValue = defaultMemorySize;
        
        driveSizeField.stringValue = String(defaultDriveSize);
        driveSizeSlider.intValue = defaultDriveSize;
        driveSizeStepper.intValue = defaultDriveSize;
        
        path.stringValue = vmLocation;
    }
    
    @IBAction func sliderChanged(_ sender: Any) {
        if (sender as? NSObject == memorySizeSlider) {
            memorySize = memorySizeSlider.intValue
            memorySizeField.stringValue = String(memorySize);
            memorySizeStepper.intValue = memorySize;
        }
        
        if (sender as? NSObject == driveSizeSlider) {
            driveSize = driveSizeSlider.intValue
            driveSizeField.stringValue = String(driveSize);
            driveSizeStepper.intValue = driveSize;
        }
    }
    
    @IBAction func textValueChanged(_ sender: Any) {
        if (sender as? NSObject == memorySizeField) {
            if memorySizeField.stringValue != "" {
                memorySize = Int32(memorySizeField.stringValue) ?? 0;
                memorySizeSlider.intValue = memorySize;
                memorySizeStepper.intValue = memorySize;
            }
        }
        
        if (sender as? NSObject == driveSizeField) {
            if driveSizeField.stringValue != "" {
                driveSize = Int32(driveSizeField.stringValue) ?? 0;
                driveSizeSlider.intValue = driveSize;
                driveSizeStepper.intValue = driveSize;
            }
        }
    }
    
    @IBAction func stepperChanged(_ sender: Any) {
        if (sender as? NSObject == memorySizeStepper) {
            memorySize = memorySizeStepper.intValue;
            memorySizeField.stringValue = String(memorySize);
            memorySizeSlider.intValue = memorySize;
        }
        
        if (sender as? NSObject == driveSizeStepper) {
            driveSize = driveSizeStepper.intValue
            driveSizeField.stringValue = String(driveSize);
            driveSizeSlider.intValue = driveSize;
        }

    }
    
    @IBAction func selectPath(_ sender: Any) {
        let panel = NSOpenPanel();
        panel.canChooseFiles = false;
        panel.canChooseDirectories = true;
        panel.allowsMultipleSelection = false;
        
        let wasOk = panel.runModal();
        if wasOk == NSApplication.ModalResponse.OK {
            self.vmLocation = panel.url?.path ?? "/Users/Vale";
            path.stringValue = vmLocation;
        }
    }
}
