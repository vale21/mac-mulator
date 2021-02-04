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
    var qemuPath: String = "";
    
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
        qemuPath = userDefaults.string(forKey: "qemuPath") ?? "";
        
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
        Utils.showDirectorySelector(uponSelection: {
            panel in
            self.vmLocation = panel.url?.path ?? vmLocation;
            path.stringValue = vmLocation;
        });
    }
    
    @IBAction func selectInstallMedia(_ sender: Any) {
        Utils.showFileSelector(fileTypes: ["img", "iso", "cdr"], uponSelection: {
            panel in
            self.installMedia = panel.url?.path ?? installMedia;
            diskImage.stringValue = installMedia
        });
    }
    
    @IBAction func createVM(_ sender: Any) {
        
        setupProgressBar(sender);
        
        let tempPath = NSTemporaryDirectory() + self.name.stringValue + ".qvm";
        let path = self.path.stringValue;
        let fullPath = path + "/" + Utils.escape(self.name.stringValue) + ".qvm";
        
        let virtualMachine = VirtualMachine(path: fullPath, displayName: self.name.stringValue, memory: self.memorySize, displayResolution: "1440x900x32", bootArg: "d");
        let virtualCD = VirtualDrive(path: self.installMedia, name: "cdrom-0", format: "raw", mediaType: "cdrom", size: 0);
        let virtualHDD = VirtualDrive(path: fullPath + "/disk-0.qcow2", name: "disk-0", format: "qcow2", mediaType: "disk", size: self.driveSize);
        
        virtualMachine.addVirtualDrive(virtualCD);
        virtualMachine.addVirtualDrive(virtualHDD);
        
        let shell = Shell();
        let dispatchQueue = DispatchQueue(label: "New VM Thread", qos: DispatchQoS.background);
        dispatchQueue.async {
            do {
                try self.createDocumentPackage(tempPath);
                
                let qemuRunner = QemuRunner();
                qemuRunner.createDiskImage(path: tempPath, virtualDrive: virtualHDD);
                
                virtualMachine.writeToPlist(tempPath + "/Info.plist");
                
                let moveCommand = "mv " + Utils.escape(tempPath) + " " + path;
                shell.runCommand(moveCommand);
                
            } catch {
                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                message: "Unable to create Virtual machine " + self.name.stringValue + ": " + error.localizedDescription)
            }
            
            DispatchQueue.main.async {
                self.rootController?.addVirtualMachine(virtualMachine)
                self.view.window?.close();
            }
        }
    }
            
    fileprivate func setupProgressBar(_ sender: Any) {
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
    
    fileprivate func changeStatusOfAllControls(enabled: Bool) {
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
    
    fileprivate func createDocumentPackage(_ fullPath: String) throws {
        let fileManager = FileManager.default;
        try fileManager.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: [FileAttributeKey.ownerAccountName: "vale"]);
    }
}
