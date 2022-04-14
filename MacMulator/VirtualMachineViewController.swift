//
//  VirtualMachineViewController.swift
//  MacMulator
//
//  Created by Vale on 27/01/21.
//

import Cocoa

class VirtualMachineViewController: NSViewController {
    
    var listenPort: Int32 = 4444;
    var rootController: RootViewController?;
  
    var boxContentView: NSView?;

    @IBOutlet weak var noVMsBox: NSBox!
    @IBOutlet weak var newVMButton: NSButton!
    @IBOutlet weak var importVMButton: NSButton!
    
    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet weak var vmDescription: NSTextField!
    
    @IBOutlet weak var vmIcon: NSImageView!
    @IBOutlet weak var vmArchitectureDesc: NSTextField!
    @IBOutlet weak var vmArchitecture: NSTextField!
    @IBOutlet weak var vmTypeDesc: NSTextField!
    @IBOutlet weak var vmType: NSTextField!
    @IBOutlet weak var vmProcessorsDesc: NSTextField!
    @IBOutlet weak var vmProcessors: NSTextField!
    @IBOutlet weak var vmMemoryDesc: NSTextField!
    @IBOutlet weak var vmMemory: NSTextField!
    @IBOutlet weak var vmHardDriveDesc: NSTextField!
    @IBOutlet weak var vmHardDrive: NSTextField!
    @IBOutlet weak var editVMButton: NSButton!
    
    @IBOutlet weak var centralBox: NSBox!
    @IBOutlet weak var centralBoxTrailingSpace: NSLayoutConstraint?
    @IBOutlet weak var centralBoxLeadingSpace: NSLayoutConstraint?
    @IBOutlet weak var centralBoxHeight: NSLayoutConstraint?
    @IBOutlet weak var centralBoxWidth: NSLayoutConstraint?
    @IBOutlet weak var centralBoxBottomSpace: NSLayoutConstraint?
    
    @IBOutlet weak var qemuUnavailableLabel: NSTextField!
    @IBOutlet weak var pauseVMButton: NSButton!
    @IBOutlet weak var startVMButton: NSButton!
    @IBOutlet weak var stopVMButton: NSButton!
    
    var temporaryPath = NSTemporaryDirectory();
    var screenshotView: NSImageView?;
    
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    @IBAction func createVM(_ sender: Any) {
        self.view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.NEW_VM_SEGUE, sender: self);
    }
    
    @IBAction func importVM(_ sender: Any) {
        Utils.showFileSelector(fileTypes: [MacMulatorConstants.VM_EXTENSION], uponSelection: { panel in NSApp.delegate?.application!(NSApp, openFile: String(panel.url!.path)) });
    }
    
    @IBAction func editVM(_ sender: Any) {
        self.view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.EDIT_VM_SEGUE, sender: rootController?.currentVm);
    }

    @IBAction
    func startVM(sender: Any) {
        
        if let vm = rootController?.currentVm {
            boxContentView = centralBox.contentView;
            let runner: VirtualMachineRunner = VirtualMachineRunnerFactory().create(listenPort: listenPort, vm: vm);
            rootController?.setRunningVM(vm, runner);
            listenPort += 1;
            if (runner.isVMRunning()) {
                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                message: "Virtual Machine " + vm.displayName + " is already running!");
            } else {
                self.setRunningStatus(true);
                if (vm.os == QemuConstants.OS_MAC && vm.architecture == QemuConstants.ARCH_X64) {
                    QemuUtils.populateOpenCoreConfig(virtualMachine: vm);
                }
                
                runner.runVM(uponCompletion: {
                    result, virtualMachine in
                    DispatchQueue.main.async {
                        self.rootController?.unsetRunningVM(virtualMachine);
                        if self.rootController?.currentVm == virtualMachine {
                            self.setRunningStatus(false);
                        }
                        
                        if (vm.os == QemuConstants.OS_MAC && vm.architecture == QemuConstants.ARCH_X64) {
                            QemuUtils.restoreOpenCoreConfigTemplate(virtualMachine: vm);
                        }
                        
                        if (result.exitCode != 0) {
                            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: "Qemu execution failed with error: " + result.error!);
                        }
                    }
                });
            }
            
            if (vm.os == QemuConstants.OS_MAC && vm.subtype == QemuConstants.SUB_MAC_MONTEREY) {
                self.performSegue(withIdentifier: MacMulatorConstants.SHOW_VM_VIEW_SEGUE, sender: vm);
            }
        }
    }
    
    @IBAction func stopVM(_ sender: Any) {
        Utils.showPrompt(window: self.view.window!, style: NSAlert.Style.warning, message: "Attention.\nThis operation will forcibly kill the running VM.\nIt is strogly suggested to shut it down gracefully using the guest OS shuit down procedure, or you might loose your unsaved work.\n\nDo you want to continue?", completionHandler:{ response in
            if response.rawValue == Utils.ALERT_RESP_OK {
                if let vm = self.rootController?.currentVm {
                    self.rootController?.getRunnerForRunningVM(vm)?.stopVM();
                }
            }
        });
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        let source = segue.sourceController as! VirtualMachineViewController;
        let dest = segue.destinationController as! VirtualMachineContainerViewController;
        
        if (segue.identifier == MacMulatorConstants.SHOW_VM_VIEW_SEGUE) {
            let vmToEdit = sender as! VirtualMachine;
            
            dest.setVirtualMachine(vmToEdit);
            dest.setVmController(source);
        }
    }
    
    override func viewWillAppear() {
        startVMButton.toolTip = "Start this VM";
        pauseVMButton.toolTip = "Pause feature is not supported yet in MacMulator.";
        stopVMButton.toolTip = "Stop the execution of this VM";
        
        self.setRunningStatus(false);
        if rootController?.currentVm != nil {
            showVMAvailableLayout();
            
            if !QemuUtils.isBinaryAvailable(rootController!.currentVm!.architecture) {
                startVMButton.isEnabled = false;
            }
        } else {
            showNoVmsLayout();
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad();
    }
    
    func setVirtualMachine(_ virtualMachine: VirtualMachine?) {
        if let vm = virtualMachine {
            vmIcon.image = NSImage.init(named: NSImage.Name(Utils.getIconForSubType(vm.os, vm.subtype) + ".large"));
            vmName.stringValue = vm.displayName;
            vmDescription.stringValue = vm.description;
            vmArchitecture.stringValue = QemuConstants.ALL_ARCHITECTURES_DESC[vm.architecture] ?? "Not Specified";
            vmType.stringValue = vm.subtype ?? Utils.getSubType(vm.os, 0);
            vmProcessors.intValue = Int32(vm.cpus);
            vmMemory.stringValue = Utils.formatMemory(vm.memory);
            
            let mainDrive = Utils.findMainDrive(vm.drives);
            vmHardDrive.stringValue = mainDrive != nil ? Utils.formatDisk(mainDrive!.size) : "Not Specified";
            showVMAvailableLayout();
            
            if rootController?.getRunnerForRunningVM(vm) != nil {
                setRunningStatus(true);
            } else {
                setRunningStatus(false);
            }
            
            if QemuUtils.isBinaryAvailable(vm.architecture) {
                startVMButton.isEnabled = true;
                qemuUnavailableLabel.isHidden = true;
            } else {
                startVMButton.isEnabled = false;
                qemuUnavailableLabel.stringValue = "The VM cannot be started because Qemu binary for artchitecture " + vmArchitecture.stringValue + " is not available."
                qemuUnavailableLabel.isHidden = false;
            }
        } else {
            showNoVmsLayout();
        }
    }
    
    fileprivate func livePreviewTimerLogic(_ timer: Timer, _ runner: VirtualMachineRunner) {
        let imageName = self.temporaryPath + String(runner.getManagedVM().displayName).lowercased().replacingOccurrences(of: " ", with: "_") + "_scr.ppm";
        
        let currentFrequency = Double(UserDefaults.standard.integer(forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE));
        if timer.timeInterval != currentFrequency {
            print("Stopping timer. Frequency changed.");
            timer.invalidate();
        } else {
            if !runner.isVMRunning() || rootController?.currentVm != runner.getManagedVM(){
                print("Stopping timer");
                timer.invalidate();
                
                let fileManager = FileManager.default;
                do {
                    try fileManager.removeItem(atPath: imageName);
                } catch {
                    print("Cannot clear temporary images: " + error.localizedDescription);
                }
            } else {
                DispatchQueue.global().async {
                    if runner.isVMRunning() {
                        let qemuRunner = runner as! QemuRunner;
                        let monitor = QemuMonitor(qemuRunner.getListenPort());
                        monitor.takeScreenshot(path: imageName);
                        monitor.close();
                    }
                }
                screenshotView?.image = NSImage(byReferencingFile: imageName);
            }
        }
    }
    
    fileprivate func setupScreenshotTimer(_ runnerIn: VirtualMachineRunner?) {
        
        if let runner = runnerIn {

            let updateFrequency = Double(UserDefaults.standard.integer(forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE));
            print("Creating timer with frequency " + String(updateFrequency));
            
            Timer.scheduledTimer(withTimeInterval: updateFrequency, repeats: true, block: { timer in
                self.livePreviewTimerLogic(timer, runner)
            });
        }
    }
        
    fileprivate func setRunningStatus(_ running: Bool) {
        self.startVMButton.isHidden = running;
        self.stopVMButton.isHidden = !running;
        self.pauseVMButton.isHidden = !running;
        
        let livePreviewEnabled = UserDefaults.standard.bool(forKey: MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED);
        
        resizeCentralBox(running && livePreviewEnabled);
        hideBoxControls(running && livePreviewEnabled);
        if livePreviewEnabled {
            centralBox.title = running ? "Live preview" : "Virtual machine features";
        }
        
        if running, livePreviewEnabled, let vm = rootController?.currentVm {
            let imagefile = NSImage.init(named: NSImage.Name("preview-loading"));
            if let image = imagefile {
                self.screenshotView = NSImageView(image: image);
                centralBox.contentView = self.screenshotView;
            }
            setupScreenshotTimer(rootController?.getRunnerForRunningVM(vm));
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
        vmTypeDesc.isHidden = hidden;
        vmType.isHidden = hidden;
        vmProcessorsDesc.isHidden = hidden;
        vmProcessors.isHidden = hidden;
        vmMemoryDesc.isHidden = hidden;
        vmMemory.isHidden = hidden;
        vmHardDriveDesc.isHidden = hidden;
        vmHardDrive.isHidden = hidden;
        editVMButton.isHidden = hidden;
    }
    
    fileprivate func showNoVmsLayout() {
        noVMsBox.isHidden = false;
        
        vmName.isHidden = true;
        vmDescription.isHidden = true;
        centralBox.isHidden = true;
        startVMButton.isHidden = true;
        qemuUnavailableLabel.isHidden = true;
    }
    
    fileprivate func showVMAvailableLayout() {
        noVMsBox.isHidden = true;
        
        vmName.isHidden = false;
        vmDescription.isHidden = false;
        centralBox.isHidden = false;
        startVMButton.isHidden = false;
        qemuUnavailableLabel.isHidden = false;
    }
}
