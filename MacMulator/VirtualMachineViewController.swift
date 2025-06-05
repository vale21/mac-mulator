//
//  VirtualMachineViewController.swift
//  MacMulator
//
//  Created by Vale on 27/01/21.
//

import Cocoa

protocol RunningVMManagerViewController {
    func setVirtualMachine(_ vm: VirtualMachine)
    func setRecoveryMode(_ recoveryMode: Bool)
    func setVmController(_ controller: VirtualMachineViewController)
    func setVmRunner(_ runner: VirtualMachineRunner)
}

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
    var listenPort: Int32 = 4444
    var rootController: RootViewController?

    var boxContentView: NSView?

    @IBOutlet var noVMsBox: NSBox!
    @IBOutlet var noVMWelcomeMessage: NSTextField!
    @IBOutlet var newVMButton: NSButton!
    @IBOutlet var newVMLabel: NSButton!
    @IBOutlet var importVMButton: NSButton!
    @IBOutlet var importVMLabel: NSButton!

    @IBOutlet var vmName: NSTextField!
    @IBOutlet var vmDescription: NSTextField!

    @IBOutlet var vmIcon: NSImageView!
    @IBOutlet var vmArchitectureDesc: NSTextField!
    @IBOutlet var vmArchitecture: NSTextField!
    @IBOutlet var vmTypeDesc: NSTextField!
    @IBOutlet var vmType: NSTextField!
    @IBOutlet var vmProcessorsDesc: NSTextField!
    @IBOutlet var vmProcessors: NSTextField!
    @IBOutlet var vmMemoryDesc: NSTextField!
    @IBOutlet var vmMemory: NSTextField!
    @IBOutlet var vmHardDriveDesc: NSTextField!
    @IBOutlet var vmHardDrive: NSTextField!
    @IBOutlet var editVMButton: NSButton!

    @IBOutlet var centralBox: NSBox!
    @IBOutlet var centralBoxTrailingSpace: NSLayoutConstraint?
    @IBOutlet var centralBoxLeadingSpace: NSLayoutConstraint?
    @IBOutlet var centralBoxHeight: NSLayoutConstraint?
    @IBOutlet var centralBoxWidth: NSLayoutConstraint?
    @IBOutlet var centralBoxBottomSpace: NSLayoutConstraint?

    @IBOutlet var qemuUnavailableLabel: NSTextField!
    @IBOutlet var pauseVMButton: NSButton!
    @IBOutlet var startVMButton: NSButton!
    @IBOutlet var stopVMButton: NSButton!

    var temporaryPath = NSTemporaryDirectory()
    var screenshotView: NSImageView?

    func setRootController(_ rootController: RootViewController) {
        self.rootController = rootController
    }

    @IBAction func createVM(_: Any) {
        view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.NEW_VM_SEGUE, sender: self)
    }

    @IBAction func importVM(_: Any) {
        Utils.showFileSelector(fileTypes: [MacMulatorConstants.VM_EXTENSION], uponSelection: { panel in _ = NSApp.delegate?.application!(NSApp, openFile: String(panel.url!.path)) })
    }

    @IBAction func editVM(_: Any) {
        view.window?.windowController?.performSegue(withIdentifier: MacMulatorConstants.EDIT_VM_SEGUE, sender: [nil, rootController?.currentVm])
    }

    @IBAction
    func startVM(sender: Any) {
        startVM(sender: sender, inRecovery: false)
    }

    @IBAction
    func pauseVM(sender _: Any) {
        if #available(macOS 14.0, *) {
            if let vm = self.rootController?.currentVm {
                if vm.type == MacMulatorConstants.APPLE_VM {
                    let runner = self.rootController?.getRunnerForRunningVM(vm) as! VirtualizationFrameworkVirtualMachineRunner
                    runner.pauseVM()
                }
            }
        }
    }

    @IBAction func stopVM(_ sender: Any) {
        var window = view.window!

        if #available(macOS 12.0, *) {
            if let vm = self.rootController?.currentVm {
                if sender as? String == MacMulatorConstants.mainMenuSender, vm.type == MacMulatorConstants.APPLE_VM {
                    let runner = self.rootController?.getRunnerForRunningVM(vm) as! VirtualizationFrameworkVirtualMachineRunner
                    window = runner.vmView!.window!
                }
            }
        }

        Utils.showPrompt(window: window, style: NSAlert.Style.warning, message: NSLocalizedString("VirtualMachineViewController.forciblyClosing", comment: ""), completionHandler: { response in
            if response.rawValue == Utils.ALERT_RESP_OK {
                if let vm = self.rootController?.currentVm {
                    self.rootController?.getRunnerForRunningVM(vm)?.stopVM(guestStopped: true)
                }
            }
        }, virtualMachine: rootController?.currentVm)
    }

    func startVMInRecovery(sender: Any) {
        startVM(sender: sender, inRecovery: true)
    }

    func attachUSBImageToVM(sender: Any, virtualDrive: VirtualDrive) {
        if #available(macOS 15.0, *) {
            if let rootController = self.rootController, let vm = rootController.currentVm, rootController.isVMRunning(vm) {
                if sender as? String == MacMulatorConstants.mainMenuSender, vm.type == MacMulatorConstants.APPLE_VM {
                    let runner = self.rootController?.getRunnerForRunningVM(vm) as! VirtualizationFrameworkVirtualMachineRunner
                    runner.attachUSBImageToVM(virtualDrive: virtualDrive)
                }
            }
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == MacMulatorConstants.SHOW_VM_VIEW_SEGUE {
            if #available(macOS 12.0, *) {
                let source = segue.sourceController as! VirtualMachineViewController
                let dest = segue.destinationController as! VirtualMachineContainerViewController
                let vmToStart = sender as! VMToStart

                dest.setVirtualMachine(vmToStart.vm)
                dest.setRecoveryMode(vmToStart.inRecovery)
                dest.setVmRunner(vmToStart.runner)
                dest.setVmController(source)
                dest.setVmRunner(rootController?.getRunnerForCurrentVM() as! VirtualizationFrameworkVirtualMachineRunner)
            }
        } else if segue.identifier == MacMulatorConstants.START_VM_SEGUE {
            let source = segue.sourceController as! VirtualMachineViewController
            let dest = segue.destinationController as! StartVMViewController
            let vmToStart = sender as! VMToStart

            dest.setVmRunner(vmToStart.runner)
            dest.setVirtualMachine(vmToStart.vm)
            dest.setRecoveryMode(vmToStart.inRecovery)
            dest.setVmController(source)
        }
    }

    func cleanupStoppedVM(_ vm: VirtualMachine) {
        rootController?.unsetRunningVM(vm)
        if rootController?.currentVm == vm {
            setRunningStatus(vm, false)
        }
    }

    override func viewWillAppear() {
        boxContentView = centralBox.contentView
        startVMButton.toolTip = NSLocalizedString("VirtualMachineViewController.startVM", comment: "")
        pauseVMButton.toolTip = NSLocalizedString("VirtualMachineViewController.pauseNotSupported", comment: "")
        stopVMButton.toolTip = NSLocalizedString("VirtualMachineViewController.stopVM", comment: "")

        setRunningStatus(nil, false)
        if rootController?.currentVm != nil {
            showVMAvailableLayout()

            if !QemuUtils.isBinaryAvailable(rootController!.currentVm!.architecture) {
                startVMButton.isEnabled = false
            }
            if Utils.isPauseSupported(rootController!.currentVm!) {
                pauseVMButton.isEnabled = true
                pauseVMButton.toolTip = NSLocalizedString("VirtualMachineViewController.pauseVM", comment: "")
            } else {
                pauseVMButton.isEnabled = false
                pauseVMButton.toolTip = NSLocalizedString("VirtualMachineViewController.pauseNotSupported", comment: "")
            }
        } else {
            showNoVmsLayout()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func setVirtualMachine(_ virtualMachine: VirtualMachine?) {
        if let vm = virtualMachine {
            vmIcon.image = NSImage(named: NSImage.Name(Utils.getIconForSubType(vm.os, vm.subtype) + ".large"))

            if let rootController {
                if rootController.isVMPaused(vm) {
                    vmName.stringValue = String(format: NSLocalizedString("VirtualMachineViewController.pausedVMName", comment: ""), vm.displayName)
                } else {
                    vmName.stringValue = vm.displayName
                }
            }

            vmDescription.stringValue = vm.description
            vmArchitecture.stringValue = QemuConstants.ALL_ARCHITECTURES_DESC[vm.architecture] ?? NSLocalizedString("VirtualMachineViewController.notSpecified", comment: "")
            vmType.stringValue = vm.subtype
            vmProcessors.intValue = Int32(vm.cpus)
            vmMemory.stringValue = Utils.formatMemory(vm.memory)

            let mainDrive = Utils.findMainDrive(vm.drives)
            vmHardDrive.stringValue = mainDrive != nil ? Utils.formatDisk(mainDrive!.size) : NSLocalizedString("VirtualMachineViewController.notSpecified", comment: "")
            showVMAvailableLayout()

            if rootController?.getRunnerForRunningVM(vm) != nil {
                setRunningStatus(vm, true)
            } else {
                setRunningStatus(vm, false)
            }

            if vm.type == nil || vm.type == MacMulatorConstants.QEMU_VM {
                if Utils.isVMAvailable(vm) {
                    startVMButton.isEnabled = true
                    qemuUnavailableLabel.isHidden = true
                } else if vm.subtype == QemuConstants.SUB_WINDOWS_11, !QemuUtils.isBinaryAvailable(QemuConstants.SWTPM) {
                    startVMButton.isEnabled = false
                    qemuUnavailableLabel.stringValue = String(format: NSLocalizedString("VirtualMachineViewController.swTpmNotAvailable", comment: ""), vmArchitecture.stringValue)
                    qemuUnavailableLabel.isHidden = false
                } else {
                    startVMButton.isEnabled = false
                    qemuUnavailableLabel.stringValue = NSLocalizedString("VirtualMachineViewController.binaryNotAvaiable", comment: "")
                    qemuUnavailableLabel.isHidden = false
                }
            } else {
                if Utils.isVMAvailable(vm) {
                    startVMButton.isEnabled = true
                    qemuUnavailableLabel.isHidden = true
                } else {
                    startVMButton.isEnabled = false
                    qemuUnavailableLabel.isHidden = false
                    qemuUnavailableLabel.stringValue = Utils.getUnavailabilityMessage(vm)
                }
            }
        } else {
            showNoVmsLayout()
        }
    }

    fileprivate func setRunningStatus(_ vm: VirtualMachine?, _ running: Bool) {
        startVMButton.isHidden = running
        stopVMButton.isHidden = !running
        pauseVMButton.isHidden = !running

        if let vm {
            if Utils.isPauseSupported(vm) {
                pauseVMButton.isEnabled = true
            } else {
                pauseVMButton.isEnabled = false
            }

            if let rootController {
                let filemanager = FileManager.default
                let screenshotExists = filemanager.fileExists(atPath: vm.path + "/" + MacMulatorConstants.SCREENSHOT_FILE_NAME)

                if rootController.isVMPaused(vm) {
                    vmName.stringValue = String(format: NSLocalizedString("VirtualMachineViewController.pausedVMName", comment: ""), vm.displayName)
                } else {
                    vmName.stringValue = vm.displayName
                }

                if rootController.isVMPaused(vm), screenshotExists {
                    resizeCentralBox(true)
                    hideBoxControls(true)

                    centralBox.title = NSLocalizedString("VirtualMachineViewController.vmPaused", comment: "")
                    let imagefile = NSImage(contentsOfFile: vm.path + "/" + MacMulatorConstants.SCREENSHOT_FILE_NAME)
                    if let image = imagefile {
                        screenshotView = NSImageView(image: image)
                        centralBox.contentView = screenshotView
                    }
                } else {
                    resizeCentralBox(false)
                    hideBoxControls(false)

                    centralBox.contentView = boxContentView
                }
            }
        }
    }

    fileprivate func resizeCentralBox(_ running: Bool) {
        if running {
            centralBoxWidth?.priority = NSLayoutConstraint.Priority.defaultLow
            centralBoxHeight?.priority = NSLayoutConstraint.Priority.defaultLow
            centralBoxTrailingSpace?.priority = NSLayoutConstraint.Priority.defaultHigh
            centralBoxLeadingSpace?.priority = NSLayoutConstraint.Priority.defaultHigh
            centralBoxBottomSpace?.priority = NSLayoutConstraint.Priority.defaultHigh
        } else {
            centralBoxWidth?.priority = NSLayoutConstraint.Priority.defaultHigh
            centralBoxHeight?.priority = NSLayoutConstraint.Priority.defaultHigh
            centralBoxTrailingSpace?.priority = NSLayoutConstraint.Priority.defaultLow
            centralBoxLeadingSpace?.priority = NSLayoutConstraint.Priority.defaultLow
            centralBoxBottomSpace?.priority = NSLayoutConstraint.Priority.defaultLow
        }
        view.layout()
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
        noVMsBox.isHidden = false

        vmName.isHidden = true
        vmDescription.isHidden = true
        centralBox.isHidden = true
        startVMButton.isHidden = true
        qemuUnavailableLabel.isHidden = true

        noVMWelcomeMessage.stringValue = NSLocalizedString("VirtualMachineViewController.noVMWelcomeMessage", comment: "")
        newVMLabel.title = NSLocalizedString("VirtualMachineViewController.newVMLabel", comment: "")
        importVMLabel.title = NSLocalizedString("VirtualMachineViewController.importVMLabel", comment: "")
    }

    fileprivate func showVMAvailableLayout() {
        noVMsBox.isHidden = true

        vmName.isHidden = false
        vmDescription.isHidden = false
        centralBox.isHidden = false
        startVMButton.isHidden = false
        qemuUnavailableLabel.isHidden = false

        centralBox.title = NSLocalizedString("VirtualMachineViewController.vmFeatures", comment: "")
        vmArchitectureDesc.stringValue = NSLocalizedString("VirtualMachineViewController.vmArchitecture", comment: "")
        vmTypeDesc.stringValue = NSLocalizedString("VirtualMachineViewController.vmType", comment: "")
        vmMemoryDesc.stringValue = NSLocalizedString("VirtualMachineViewController.vmMemory", comment: "")
        vmProcessorsDesc.stringValue = NSLocalizedString("VirtualMachineViewController.vmProcessors", comment: "")
        vmHardDriveDesc.stringValue = NSLocalizedString("VirtualMachineViewController.vmHardDrive", comment: "")
        editVMButton.title = NSLocalizedString("VirtualMachineViewController.editVMButton", comment: "")
    }

    func startVMPrerequisitesCompleted(_ runner: any VirtualMachineRunner, _ inRecovery: Bool, _ vm: VirtualMachine) {
        startVM_internal(runner, inRecovery, vm)
    }

    fileprivate func startVM_internal(_ runner: any VirtualMachineRunner, _ inRecovery: Bool, _ vm: VirtualMachine) {
        do {
            if vm.subtype == QemuConstants.SUB_WINDOWS_11 {
                let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!
                let swTpmPath = vm.qemuPath != nil ? vm.qemuPath! : qemuPath
                let shell = Shell()
                shell.runCommand(swTpmPath + "/swtpm socket --tpmstate dir=" + Utils.escape(vm.path) + "/tpm  --ctrl type=unixio,path=" + Utils.escape(vm.path) + "/tpm/socket  --log level=20 --tpm2", vm.path, uponCompletion: { _ in
                    print("swtpm done")
                })
            }
            try runner.runVM(recoveryMode: inRecovery, uponCompletion: {
                result, virtualMachine in
                self.completionhandler(result: result, virtualMachine: virtualMachine)
            })
        } catch let error as ValidationError {
            completionhandler(result: VMExecutionResult(exitCode: -1, error: error.description), virtualMachine: vm)
        } catch {
            print(error.localizedDescription)
        }
    }

    fileprivate func startVM(sender _: Any, inRecovery: Bool) {
        if let rootController {
            if let vm = rootController.currentVm {
                listenPort += 1
                let runner: VirtualMachineRunner = VirtualMachineRunnerFactory().create(listenPort: listenPort, vm: vm)

                setRunningStatus(vm, true)
                rootController.setRunningVM(vm, runner)

                if vm.bootMode == nil {
                    vm.bootMode = Utils.getBootModeForSubType(vm.os, vm.subtype)
                    vm.writeToPlist()
                }

                if vm.type == MacMulatorConstants.APPLE_VM {
                    performSegue(withIdentifier: MacMulatorConstants.SHOW_VM_VIEW_SEGUE, sender: VMToStart(vm: vm, inRecovery: inRecovery, runner: runner))
                } else {
                    if vm.bootMode == QemuConstants.BOOT_UEFI || vm.bootMode == QemuConstants.BOOT_UEFI_SECURE || (vm.os == QemuConstants.OS_MAC && vm.architecture == QemuConstants.ARCH_X64) {
                        performSegue(withIdentifier: MacMulatorConstants.START_VM_SEGUE, sender: VMToStart(vm: vm, inRecovery: inRecovery, runner: runner))
                    } else {
                        startVM_internal(runner, inRecovery, vm)
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
                    if QemuUtils.requiresOpenCore(vm) {
                        QemuUtils.removeOpenCoreConfig(virtualMachine: vm, uponCompletion: {
                            terminationCode in
                            if terminationCode != 0 {
                                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("VirtualMachineViewController.vmExecutionFailed", comment: ""), result.error?.localizedCapitalized ?? NSLocalizedString("VirtualMachineViewController.notSpecified", comment: "")))
                            }
                        })
                    }
                }
            }

            if result.exitCode != 0 {
                Utils.showAlert(window: self.view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("VirtualMachineViewController.vmExecutionFailed", comment: ""), result.error?.localizedCapitalized ?? NSLocalizedString("VirtualMachineViewController.notSpecified", comment: "")))
            }
        }
    }
}
