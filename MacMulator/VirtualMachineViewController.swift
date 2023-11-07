//
//  VirtualMachineViewController.swift
//  MacMulator
//
//  Created by Vale on 27/01/21.
//

import Cocoa

class VMToStart {
    var vm: VirtualMachine
    var inRecovery: Bool
    var runner: VirtualMachineRunner
    
    init(vm: VirtualMachine, inRecovery: Bool, runner: VirtualMachineRunner) {
        self.vm = vm
        self.inRecovery = inRecovery
        self.runner = runner
    }
}

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
    
    func startVMInRecovery(sender: Any) {
        startVM(sender: sender, inRecovery: true)
    }
    
    @IBAction
    func startVM(sender: Any) {
        startVM(sender: sender, inRecovery: false)
    }
    
    @IBAction
    func pauseVM(sender: Any) {
        if #available(macOS 14.0, *) {
            if let vm = self.rootController?.currentVm  {
                if vm.type == MacMulatorConstants.APPLE_VM {
                    let runner = self.rootController?.getRunnerForRunningVM(vm) as! VirtualizationFrameworkVirtualMachineRunner
                    runner.pauseVM()
                }
            }
        }
    }
    
    @IBAction func stopVM(_ sender: Any) {
        var window = self.view.window!
        
        if #available(macOS 12.0, *) {
            if let vm = self.rootController?.currentVm  {
                if sender as? String == "MainMenu" && vm.type == MacMulatorConstants.APPLE_VM {
                    let runner = self.rootController?.getRunnerForRunningVM(vm) as! VirtualizationFrameworkVirtualMachineRunner
                    window = runner.vmView!.window!
                }
            }
        }
        
        Utils.showPrompt(window: window, style: NSAlert.Style.warning, message: "Attention.\nThis operation will forcibly kill the running VM.\nIt is strogly suggested to shut it down gracefully using the guest OS shuit down procedure, or you might loose your unsaved work.\n\nDo you want to continue?", completionHandler:{ response in
            if response.rawValue == Utils.ALERT_RESP_OK {
                if let vm = self.rootController?.currentVm {
                    self.rootController?.getRunnerForRunningVM(vm)?.stopVM(guestStopped: true)
                }
            }
        });
    }
        
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        if #available(macOS 12.0, *) {
            let source = segue.sourceController as! VirtualMachineViewController;
            let dest = segue.destinationController as! VirtualMachineContainerViewController;
            
            if (segue.identifier == MacMulatorConstants.SHOW_VM_VIEW_SEGUE) {
                let vmToStart = sender as! VMToStart
                
                dest.setVirtualMachine(vmToStart.vm)
                dest.setRecoveryMode(vmToStart.inRecovery)
                dest.setVmRunner(vmToStart.runner)
                dest.setVmController(source)
                dest.setVmRunner(rootController?.getRunnerForCurrentVM() as! VirtualizationFrameworkVirtualMachineRunner)
            }
        }
    }
        
    func cleanupStoppedVM(_ vm: VirtualMachine) {
        rootController?.unsetRunningVM(vm)
        if self.rootController?.currentVm == vm {
            self.setRunningStatus(vm, false);
        }
    }
    
    override func viewWillAppear() {
        boxContentView = centralBox.contentView
        startVMButton.toolTip = "Start this VM";
        pauseVMButton.toolTip = "Pause feature is supported only for Apple Silicon macOS Guests";
        stopVMButton.toolTip = "Stop the execution of this VM";
        
        self.setRunningStatus(nil, false);
        if rootController?.currentVm != nil {
            showVMAvailableLayout()
            
            if !QemuUtils.isBinaryAvailable(rootController!.currentVm!.architecture) {
                startVMButton.isEnabled = false
            }
            if Utils.isPauseSupported(rootController!.currentVm!) {
                pauseVMButton.isEnabled = true
            } else {
                pauseVMButton.isEnabled = true
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
            vmIcon.image = NSImage.init(named: NSImage.Name(Utils.getIconForSubType(vm.os, vm.subtype) + ".large"))
            
            if let rootController = rootController {
                if rootController.isVMPaused(vm) {
                    vmName.stringValue = vm.displayName + " (Paused)"
                } else {
                    vmName.stringValue = vm.displayName
                }
            }
            
            vmDescription.stringValue = vm.description;
            vmArchitecture.stringValue = QemuConstants.ALL_ARCHITECTURES_DESC[vm.architecture] ?? "Not Specified"
            vmType.stringValue = vm.subtype
            vmProcessors.intValue = Int32(vm.cpus);
            vmMemory.stringValue = Utils.formatMemory(vm.memory);
            
            let mainDrive = Utils.findMainDrive(vm.drives);
            vmHardDrive.stringValue = mainDrive != nil ? Utils.formatDisk(mainDrive!.size) : "Not Specified"
            showVMAvailableLayout();
            
            if rootController?.getRunnerForRunningVM(vm) != nil {
                setRunningStatus(vm, true);
            } else {
                setRunningStatus(vm, false);
            }
            
            if vm.type == nil || vm.type == MacMulatorConstants.QEMU_VM {
                if Utils.isVMAvailable(vm) {
                    startVMButton.isEnabled = true;
                    qemuUnavailableLabel.isHidden = true;
                } else {
                    startVMButton.isEnabled = false;
                    qemuUnavailableLabel.stringValue = "The VM cannot be started because Qemu binary for artchitecture " + vmArchitecture.stringValue + " is not available."
                    qemuUnavailableLabel.isHidden = false;
                }
            } else {
                if Utils.isVMAvailable(vm) {
                    startVMButton.isEnabled = true;
                    qemuUnavailableLabel.isHidden = true;
                } else {
                    startVMButton.isEnabled = false;
                    qemuUnavailableLabel.isHidden = false;
                    qemuUnavailableLabel.stringValue = Utils.getUnavailabilityMessage(vm)
                }
            }
        } else {
            showNoVmsLayout();
        }
    }

    fileprivate func setRunningStatus(_ vm: VirtualMachine?, _ running: Bool) {
        self.startVMButton.isHidden = running
        self.stopVMButton.isHidden = !running
        self.pauseVMButton.isHidden = !running
        
        if let vm = vm {
            if Utils.isPauseSupported(vm) {
                pauseVMButton.isEnabled = true
            } else {
                pauseVMButton.isEnabled = false
            }
            
            if let rootController = rootController {
                let filemanager = FileManager.default
                let screenshotExists = filemanager.fileExists(atPath: vm.path + "/" + MacMulatorConstants.SCREENSHOT_FILE_NAME)
                    
                vmName.stringValue = vm.displayName
                
                if rootController.isVMPaused(vm) && screenshotExists {
                    resizeCentralBox(true)
                    hideBoxControls(true)
                
                    centralBox.title = "VM paused"
                    let imagefile = NSImage.init(contentsOfFile: vm.path + "/" + MacMulatorConstants.SCREENSHOT_FILE_NAME)
                    if let image = imagefile {
                        screenshotView = NSImageView(image: image)
                        centralBox.contentView = screenshotView
                    }
                } else {
                    resizeCentralBox(false)
                    hideBoxControls(false)
                    
                    centralBox.title = "Virtual Machine Features"
                    centralBox.contentView = boxContentView
                }
            }
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
        vmIcon.isHidden = hidden
        vmArchitectureDesc.isHidden = hidden
        vmArchitecture.isHidden = hidden
        vmTypeDesc.isHidden = hidden
        vmType.isHidden = hidden
        vmProcessorsDesc.isHidden = hidden
        vmProcessors.isHidden = hidden
        vmMemoryDesc.isHidden = hidden
        vmMemory.isHidden = hidden
        vmHardDriveDesc.isHidden = hidden
        vmHardDrive.isHidden = hidden
        editVMButton.isHidden = hidden
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
    
    fileprivate func startVM(sender: Any, inRecovery: Bool) {
        if let rootController = self.rootController {
            if let vm = rootController.currentVm {
                
                if (rootController.isVMRunning(vm)) {
                    Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical,
                                    message: "Virtual Machine " + vm.displayName + " is already running!");
                } else {
                    listenPort += 1;
                    let runner: VirtualMachineRunner = VirtualMachineRunnerFactory().create(listenPort: listenPort, vm: vm);
                    
                    self.setRunningStatus(vm, true);
                    rootController.setRunningVM(vm, runner);
                    
                    if vm.type == MacMulatorConstants.APPLE_VM {
                        self.performSegue(withIdentifier: MacMulatorConstants.SHOW_VM_VIEW_SEGUE, sender: VMToStart(vm: vm, inRecovery: inRecovery, runner: runner));
                    } else {
                        if (vm.os == QemuConstants.OS_MAC && vm.architecture == QemuConstants.ARCH_X64) {
                            QemuUtils.populateOpenCoreConfig(virtualMachine: vm);
                        }
                        
                        do {
                            try runner.runVM(recoveryMode: inRecovery, uponCompletion: {
                                result, virtualMachine in
                                self.completionhandler(result: result, virtualMachine: virtualMachine)
                            });
                        } catch let error as ValidationError {
                            completionhandler(result: VMExecutionResult(exitCode: -1, error: error.description), virtualMachine: vm)
                        } catch {
                            print (error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func completionhandler(result: VMExecutionResult, virtualMachine: VirtualMachine) {
        DispatchQueue.main.async {
            self.cleanupStoppedVM(virtualMachine)
            
            if let rootController = self.rootController {
                if let vm = rootController.currentVm {
                    if (vm.os == QemuConstants.OS_MAC && vm.architecture == QemuConstants.ARCH_X64) {
                        QemuUtils.restoreOpenCoreConfigTemplate(virtualMachine: vm);
                    }
                }
            }
            
            if (result.exitCode != 0) {
                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: "VM execution failed with error: " + result.error!);
            }
        }
    }
}
