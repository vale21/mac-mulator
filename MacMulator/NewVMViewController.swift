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
    var vmLocation: String = "";
    var installMedia: String = "";
    
    var rootController : RootViewController?
    

    @IBOutlet weak var name: NSTextField!
    @IBOutlet weak var path: NSTextField!
    @IBOutlet weak var findPathButton: NSButton!
    
    @IBOutlet weak var memorySizeField: NSTextField!
    @IBOutlet weak var memorySizeSlider: NSSlider!
    @IBOutlet weak var memorySizeStepper: NSStepper!
    
    @IBOutlet weak var diskImage: NSTextField!
    @IBOutlet weak var findDiskImageButton: NSButton!
    
    @IBOutlet weak var driveSizeField: NSTextField!
    @IBOutlet weak var driveSizeSlider: NSSlider!
    @IBOutlet weak var driveSizeStepper: NSStepper!

    @IBOutlet weak var createButton: NSButton!
    @IBOutlet weak var shadingView: NSView!
    @IBOutlet weak var progressBarContainer: NSView!
    @IBOutlet weak var progressBarDescription: NSTextField!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    
    
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }

    override func viewDidLoad() {
            
        let userDefaults = UserDefaults.standard;
        vmLocation = userDefaults.string(forKey: "libraryPath") ?? "";
        
        memorySizeField.stringValue = String(defaultMemorySize);
        memorySizeSlider.intValue = defaultMemorySize;
        memorySizeStepper.intValue = defaultMemorySize;
        
        driveSizeField.stringValue = String(defaultDriveSize);
        driveSizeSlider.intValue = defaultDriveSize;
        driveSizeStepper.intValue = defaultDriveSize;
        
        path.stringValue = vmLocation;
    
        shadingView.isHidden = true;
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
            self.vmLocation = panel.url?.path ?? vmLocation;
            path.stringValue = vmLocation;
        }
    }
    
    @IBAction func selectInstallMedia(_ sender: Any) {
        let panel = NSOpenPanel();
        panel.canChooseFiles = true;
        panel.canChooseDirectories = false;
        panel.allowsMultipleSelection = false;
        panel.allowedFileTypes = ["img", "iso", "cdr"];
        panel.allowsOtherFileTypes = true;
        
        let wasOk = panel.runModal();
        if wasOk == NSApplication.ModalResponse.OK {
            self.installMedia = panel.url?.path ?? installMedia;
            diskImage.stringValue = installMedia;
        }
    }
    
    @IBAction func createVM(_ sender: Any) {
        
        setupProgressBar(sender);
        
        let fileManager = FileManager.default;
        
        do {
            let fullPath = (path.stringValue + "/" + name.stringValue + ".qvm");
            print(fullPath);
            try fileManager.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: nil);
        } catch {
            print("ERROR while reading: " + error.localizedDescription);
        }
                
        let virtualCD = VirtualDrive(name: diskImage.stringValue, format: "raw", mediaType: "cdrom");
        let virtualHDD = VirtualDrive(name: "disk-0", format: "qcow2", mediaType: "disk");
        
        let vm = VirtualMachine(displayName: name.stringValue, memory: memorySize, displayResolution: "1440x900X32", bootArg: "d");
        vm.addVirtualDrive(virtualCD);
        vm.addVirtualDrive(virtualHDD);
        
        rootController?.addVirtualMachine(vm);
        

        self.view.window?.close();
    }
    
    func setupProgressBar(_ sender: Any) {
        shadingView.layer?.backgroundColor = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5);
        if let blurFilter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 2]) {
            shadingView.layer?.backgroundFilters = [blurFilter];
        }
        shadingView.isHidden = false;
        progressBar.startAnimation(sender);
        progressBarContainer.layer?.backgroundColor = CGColor.white;
        progressBarContainer.layer?.shadowRadius = 8
        progressBarContainer.layer?.shadowOffset = CGSize(width: 3, height: 3)
        progressBarContainer.layer?.shadowOpacity = 0.5
        progressBarContainer.layer?.cornerRadius = 20;
        progressBarDescription.stringValue = "Creating " + name.stringValue + "...";
        changeStatusOfAllControls(enabled: false);
    }

    func changeStatusOfAllControls(enabled: Bool) {
        name.isEnabled = enabled;
        path.isEnabled = enabled;
        findPathButton.isEnabled = enabled;
        memorySizeField.isEnabled = enabled;
        memorySizeSlider.isEnabled = enabled;
        memorySizeStepper.isEnabled = enabled;
        diskImage.isEnabled = enabled;
        findDiskImageButton.isEnabled = enabled;
        driveSizeField.isEnabled = enabled;
        driveSizeSlider.isEnabled = enabled;
        driveSizeStepper.isEnabled = enabled;
        createButton.isEnabled = enabled;
    }
}
