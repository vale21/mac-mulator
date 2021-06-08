//
//  VirtualMachineViewController.swift
//  MacMulator
//
//  Created by Vale on 27/01/21.
//

import Cocoa

class VirtualMachineViewController: NSViewController {
    
    var listenPort: Int32 = 4444;
    var vm : VirtualMachine?;
    var rootController: RootViewController?;
    var runningVMs: [VirtualMachine : QemuRunner] = [:];
    
    var boxContentView: NSView?;

    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet weak var vmDescription: NSTextField!
    
    @IBOutlet weak var vmIcon: NSImageView!
    @IBOutlet weak var vmArchitectureDesc: NSTextField!
    @IBOutlet weak var vmArchitecture: NSTextField!
    @IBOutlet weak var vmProcessorsDesc: NSTextField!
    @IBOutlet weak var vmProcessors: NSTextField!
    @IBOutlet weak var vmMemoryDesc: NSTextField!
    @IBOutlet weak var vmMemory: NSTextField!
    @IBOutlet weak var vmHardDriveDesc: NSTextField!
    @IBOutlet weak var vmHardDrive: NSTextField!
    @IBOutlet weak var vmResolutionDesc: NSTextField!
    @IBOutlet weak var vmResolution: NSTextField!
    @IBOutlet weak var editVMButton: NSButton!
    
    @IBOutlet weak var centralBox: NSBox!
    @IBOutlet weak var centralBoxTrailingSpace: NSLayoutConstraint?
    @IBOutlet weak var centralBoxLeadingSpace: NSLayoutConstraint?
    @IBOutlet weak var centralBoxHeight: NSLayoutConstraint?
    @IBOutlet weak var centralBoxWidth: NSLayoutConstraint?
    @IBOutlet weak var centralBoxBottomSpace: NSLayoutConstraint?
    
    @IBOutlet weak var pauseVMButton: NSButton!
    @IBOutlet weak var startVMButton: NSButton!
    @IBOutlet weak var stopVMButton: NSButton!
    
    var temporaryPath = NSTemporaryDirectory();
    var screenshotView: NSImageView?;

    override func viewWillAppear() {
        self.setRunningStatus(false);
        if self.vm != nil {
            //changeStatusOfAllControls(hidden: false);
            
            if !QemuUtils.isBinaryAvailable(vm!.architecture) {
                startVMButton.isEnabled = false;
            }
        } else {
            //changeStatusOfAllControls(hidden: true);
            startVMButton.isHidden = true;
        }
    }
    
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    @IBAction func editVM(_ sender: Any) {
        self.view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.EDIT_VM_SEGUE, sender: vm);
    }
    
    @IBAction
    func startVM(sender: NSButton) {
        
        if let vm = self.vm {
            boxContentView = centralBox.contentView;
            let runner = QemuRunner(listenPort: listenPort, virtualMachine: vm);
            runningVMs[vm] = runner;
            listenPort += 1;
            if (runner.isRunning()) {
                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                message: "Virtual Machine " + vm.displayName + " is already running!");
            } else {
                self.setRunningStatus(true);
                runner.runVM(uponCompletion: {
                    virtualMachine in
                    DispatchQueue.main.async {
                        self.runningVMs.removeValue(forKey: virtualMachine);
                        self.setRunningStatus(false);
                    }
                });
                
                setupScreenshotTimer(runner);
            }
        }
    }
    
    @IBAction func stopVM(_ sender: Any) {
        Utils.showPrompt(window: self.view.window!, style: NSAlert.Style.warning, message: "Attention.\nThis operation will forcibly kill the running VM.\nIt is strogly suggested to shut it down gracefully using the guest OS shuit down procedure, or you might loose your unsaved work.\n\nDo you want to continue?", completionHandler:{ response in
            if response.rawValue == Utils.ALERT_RESP_OK {
                if let vm = self.vm {
                    self.runningVMs[vm]?.kill();
                }
            }
        });
    }
    
    override func viewDidLoad() {
        super.viewDidLoad();
    }
    
    fileprivate func setupScreenshotTimer(_ runner: QemuRunner) {
        
        var even = 0;
        var odd = 1;
        
        let updateFrequency = 5.0;
        
        if updateFrequency > 1 {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: false, block: { timer in
                // take initial shot after 1s
                let imageName_initial = self.temporaryPath + String(runner.virtualMachine.displayName) + "_scr_" + String(odd) + ".ppm";
                let monitor = QemuMonitor(runner.listenPort);
                monitor.takeScreenshot(path: imageName_initial);
                monitor.close();
            });
        }

        Timer.scheduledTimer(withTimeInterval: updateFrequency, repeats: true, block: { timer in
    
            let imageName_even = self.temporaryPath + String(runner.virtualMachine.displayName) + "_scr_" + String(even) + ".ppm";
            let imageName_odd = self.temporaryPath + String(runner.virtualMachine.displayName) + "_scr_" + String(odd) + ".ppm";
            
            if !runner.isRunning() || runner.virtualMachine != self.vm {
                timer.invalidate();
                
                let fileManager = FileManager.default;
                do {
                    try fileManager.removeItem(atPath: imageName_even);
                    try fileManager.removeItem(atPath: imageName_odd);
                } catch {
                    print("Cannot clear temporary images: " + error.localizedDescription);
                }
            } else {
                DispatchQueue.global().async {
                    if runner.isRunning() {
                        let monitor = QemuMonitor(runner.listenPort);
                        monitor.takeScreenshot(path: imageName_even);
                        monitor.close();
                    }
                }
                self.screenshotView?.image = NSImage(byReferencingFile: imageName_odd);
                
                // swap even and odd
                let temp = even;
                even = odd;
                odd = temp;
            }
        });
    }
    
    func setVirtualMachine(_ virtualMachine: VirtualMachine?) {
        if let vm = virtualMachine {
            self.vm = virtualMachine;
            
            vmIcon.image = NSImage.init(named: NSImage.Name(vm.os + "-large"));
            vmName.stringValue = vm.displayName;
            vmDescription.stringValue = vm.description;
            vmArchitecture.stringValue = QemuConstants.ALL_ARCHITECTURES_DESC[vm.architecture] ?? "Not Specified";
            vmProcessors.intValue = Int32(vm.cpus);
            vmMemory.stringValue = Utils.formatMemory(vm.memory);
            
            let mainDrive = Utils.findMainDrive(vm.drives);
            vmHardDrive.stringValue = mainDrive != nil ? Utils.formatDisk(mainDrive!.size) : "Not Specified";
            vmResolution.stringValue = QemuConstants.ALL_RESOLUTIONS_DESC[vm.displayResolution] ?? "Not Specified";
            
            if (runningVMs[vm] != nil) {
                setRunningStatus(true);
            } else {
                setRunningStatus(false);
            }
            //changeStatusOfAllControls(hidden: false);
            
            if QemuUtils.isBinaryAvailable(vm.architecture) {
                startVMButton.isEnabled = true;
            } else {
                startVMButton.isEnabled = false;
            }
        } else {
            //changeStatusOfAllControls(hidden: true);
            startVMButton.isHidden = true;
        }
    }
        
    fileprivate func setRunningStatus(_ running: Bool) {
        self.startVMButton.isHidden = running;
        self.stopVMButton.isHidden = !running;
        self.pauseVMButton.isHidden = !running;
        
        centralBox.title = running ? "Live preview" : "Virtual machine features";
        resizeCentralBox(running);
        hideBoxControls(running);
        
        if running {
            let imagefile = NSImage(contentsOfFile: "/Users/vale/Pictures/Wallpaper/Anna_Kournikova_1210200235157PM58.JPG");
            if let image = imagefile {
                self.screenshotView = NSImageView(image: image);
                centralBox.contentView = self.screenshotView;
            }
            setupScreenshotTimer(runningVMs[vm!]!);
        } else if boxContentView != nil {
            centralBox.contentView = boxContentView;
        }
    }
    
    fileprivate func resizeCentralBox(_ running: Bool) {
        if running {
            centralBoxWidth?.priority = NSLayoutConstraint.Priority.defaultLow;
            centralBoxHeight?.priority = NSLayoutConstraint.Priority.defaultLow;
            centralBoxTrailingSpace?.priority = NSLayoutConstraint.Priority.defaultHigh;
            centralBoxLeadingSpace?.priority = NSLayoutConstraint.Priority.defaultHigh;
            centralBoxBottomSpace?.priority = NSLayoutConstraint.Priority.defaultHigh;
        } else {
            centralBoxWidth?.priority = NSLayoutConstraint.Priority.defaultHigh;
            centralBoxHeight?.priority = NSLayoutConstraint.Priority.defaultHigh;
            centralBoxTrailingSpace?.priority = NSLayoutConstraint.Priority.defaultLow;
            centralBoxLeadingSpace?.priority = NSLayoutConstraint.Priority.defaultLow;
            centralBoxBottomSpace?.priority = NSLayoutConstraint.Priority.defaultLow;
        }
        self.view.layout();
    }
    
    fileprivate func hideBoxControls(_ hidden: Bool) {
        vmIcon.isHidden = hidden;
        vmArchitectureDesc.isHidden = hidden;
        vmArchitecture.isHidden = hidden;
        vmProcessorsDesc.isHidden = hidden;
        vmProcessors.isHidden = hidden;
        vmMemoryDesc.isHidden = hidden;
        vmMemory.isHidden = hidden;
        vmHardDriveDesc.isHidden = hidden;
        vmHardDrive.isHidden = hidden;
        vmResolutionDesc.isHidden = hidden;
        vmResolution.isHidden = hidden;
        editVMButton.isHidden = hidden;
    }

    @IBAction func createVMButtonClicked(_ sender: Any) {
        self.view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.NEW_VM_SEGUE, sender: self);
    }
    
    @IBAction func importVMButtonClicked(_ sender: Any) {
        Utils.showFileSelector(fileTypes: [MacMulatorConstants.VM_EXTENSION], uponSelection: { panel in NSApp.delegate?.application!(NSApp, openFile: String(panel.url!.path)) });
    }
    
}
