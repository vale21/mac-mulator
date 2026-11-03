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
    var runner: VirtualMachineRunner?
    /// True when the VM window (or the Spice viewer) is opened as a session on an already running headless VM
    var session: Bool

    init(vm: VirtualMachine, inRecovery: Bool, runner: VirtualMachineRunner?, session: Bool = false) {
        self.vm = vm
        self.inRecovery = inRecovery
        self.runner = runner
        self.session = session
    }
}

/// The actions opening a session on a VM (screen, SSH, terminal): whether they are shown and enabled, and why not.
/// Shared by the VM menu and the headless panel of the VM view, so that they always agree
struct VMSessionActions {
    struct Action {
        var isHidden: Bool
        /// Nil when the action is enabled
        var disabledReason: String?

        var isEnabled: Bool { disabledReason == nil }
    }

    let screenTitle: String
    let screen: Action
    let ssh: Action
    let terminal: Action

    init(vm: VirtualMachine, isRunning running: Bool) {
        let isAppleVM = vm.type == MacMulatorConstants.APPLE_VM
        screenTitle = NSLocalizedString(isAppleVM ? "AppDelegate.showVMScreen" : "AppDelegate.openSpiceSession", comment: "")

        #if APPSTORE
            let sshHidden = true
        #else
            let sshHidden = vm.os != QemuConstants.OS_LINUX && vm.os != QemuConstants.OS_MAC
        #endif

        let notRunningReason: String? = if Utils.isVMTemplate(vm) {
            NSLocalizedString("VirtualMachineViewController.sessionTemplate", comment: "")
        } else if !running {
            NSLocalizedString("VirtualMachineViewController.sessionVMNotRunning", comment: "")
        } else {
            nil
        }

        var screenReason = notRunningReason
        var sshReason = notRunningReason
        if !isAppleVM, screenReason == nil, !QemuUtils.isSpiceSupported(vm) {
            screenReason = NSLocalizedString("VirtualMachineViewController.sessionSpiceNotEnabled", comment: "")
        }
        if !isAppleVM, sshReason == nil, QemuUtils.sshPortMapping(for: vm) == nil {
            sshReason = NSLocalizedString("VirtualMachineViewController.sessionNoSshPortMapping", comment: "")
        }

        screen = Action(isHidden: !Utils.isHeadless(vm), disabledReason: screenReason)
        ssh = Action(isHidden: sshHidden, disabledReason: sshReason)
        terminal = Action(isHidden: vm.os != QemuConstants.OS_LINUX, disabledReason: notRunningReason)
    }
}

class VirtualMachineViewController: NSViewController {
    var listenPort: Int32 = 4444
    var rootController: RootViewController?

    private weak var spiceViewer: QemuSpiceViewerViewController?

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

    /// Shown in the central box, in place of the VM details, when the VM is headless. It is a top level view of the
    /// scene, attached to and detached from the box as needed
    @IBOutlet var headlessView: NSView!
    @IBOutlet var headlessLabel: NSTextField!
    @IBOutlet var screenSessionButton: NSButton!
    @IBOutlet var sshSessionButton: NSButton!
    @IBOutlet var terminalSessionButton: NSButton!

    @IBOutlet var centralBox: NSBox!
    @IBOutlet var centralBoxTrailingSpace: NSLayoutConstraint?
    @IBOutlet var centralBoxLeadingSpace: NSLayoutConstraint?
    @IBOutlet var centralBoxHeight: NSLayoutConstraint?
    @IBOutlet var centralBoxWidth: NSLayoutConstraint?
    @IBOutlet var centralBoxBottomSpace: NSLayoutConstraint?

    @IBOutlet var bottomConfigureVMButton: NSButton!
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

    @IBAction func openScreenSessionClicked(_: Any) {
        openScreenSession()
    }

    @IBAction func openSSHSessionClicked(_: Any) {
        openSSHSession()
    }

    @IBAction func openTerminalSessionClicked(_: Any) {
        openTerminalSession()
    }

    @IBAction func stopVM(_ sender: Any) {
        var window = view.window!

        if let vm = rootController?.currentVm {
            if sender as? String == MacMulatorConstants.mainMenuSender, vm.type == MacMulatorConstants.APPLE_VM {
                let runner = rootController?.getRunnerForRunningVM(vm) as! VirtualizationFrameworkVirtualMachineRunner
                // A headless VM has no window: ask on the main one
                window = runner.vmView?.window ?? window
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

    @available(macOS 13.0, *)
    func convertToQemuMenuBarClicked(_: Any, _: Bool = true) {
        guard let rootController, !rootController.isCurrentVMRunning(), rootController.currentVm?.hasLinkedDrives != true else { return }
        performSegue(withIdentifier: MacMulatorConstants.CONVERT_VM_SEGUE, sender: ConversionOperations.convertToQemu)
    }

    @available(macOS 13.0, *)
    func convertToAppleMenuBarClicked(_: Any) {
        guard let rootController, !rootController.isCurrentVMRunning(), rootController.currentVm?.hasLinkedDrives != true else { return }
        performSegue(withIdentifier: MacMulatorConstants.CONVERT_VM_SEGUE, sender: ConversionOperations.convertToApple)
    }

    @available(macOS 13.0, *)
    func convertToTemplateMenuBarClicked(_: Any) {
        guard let rootController, !rootController.isCurrentVMRunning() else { return }
        performSegue(withIdentifier: MacMulatorConstants.CONVERT_VM_SEGUE, sender: ConversionOperations.convertToTemplate)
    }

    @available(macOS 13.0, *)
    func convertToFullClone(_ vm: VirtualMachine) {
        guard let rootController, !rootController.isVMRunning(vm) else { return }
        // The conversion window works on the current VM.
        if rootController.currentVm !== vm {
            rootController.setCurrentVirtualMachine(vm)
        }
        performSegue(withIdentifier: MacMulatorConstants.CONVERT_VM_SEGUE, sender: ConversionOperations.convertToFullClone)
    }

    func vmConvertedToFullClone(_ vm: VirtualMachine, _ error: String?) {
        vm.writeToPlist()
        rootController?.refreshViewForVM(vm)
        (NSApp.delegate as? AppDelegate)?.refreshVMMenus()
        if let error {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("RootViewController.convertToFullCloneFailed", comment: ""), error), virtualMachine: vm)
        }
    }

    func vmConverted(_ vm: VirtualMachine) {
        setVirtualMachine(vm)
        if Utils.isVMTemplate(vm) {
            rootController?.setCurrentVirtualMachine(vm)
        } else if vm.type == MacMulatorConstants.QEMU_VM {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.informational, message: NSLocalizedString("RootViewController.vmConvertedToQemu", comment: ""), virtualMachine: vm)
        } else {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.informational, message: NSLocalizedString("RootViewController.vmConvertedToApple", comment: ""), virtualMachine: vm)
        }
    }

    func vmFailedConversion(_ vm: VirtualMachine, _ error: String) {
        if vm.type == MacMulatorConstants.QEMU_VM {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.informational, message: String(format: NSLocalizedString("VirtualMachineViewController.conversionToQemuFailed", comment: ""), error), virtualMachine: vm)
        } else {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.informational, message: String(format: NSLocalizedString("VirtualMachineViewController.conversionToAppleFailed", comment: ""), error), virtualMachine: vm)
        }
    }

    func cloneVirtualMachine(_ vm: VirtualMachine) {
        performSegue(withIdentifier: MacMulatorConstants.SHOW_CLONE_VIEW_SEGUE, sender: VMToStart(vm: vm, inRecovery: false, runner: nil))
    }

    func createVMSnapshot(sender _: Any) {
        if let vm = rootController?.currentVm, let rootController {
            do {
                if rootController.isVMRunning(vm) {
                    _ = try rootController.getRunnerForRunningVM(vm)?.createVMSnapshot()
                } else {
                    let tempRunner = Utils.createDummyRunnerForStoppedVM(vm)
                    _ = try tempRunner.createVMSnapshot { _ in
                        Utils.showAlert(window: self.view.window!, style: NSAlert.Style.informational, message: NSLocalizedString("VirtualMachineViewController.snapshotCreatedSuccessfully", comment: ""), virtualMachine: vm)
                    }
                }
            } catch let error as ValidationError {
                Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("VirtualMachineViewController.couldNotCreateSnapshot", comment: ""), error.description), virtualMachine: vm)
            } catch {
                Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("VirtualMachineViewController.couldNotCreateSnapshot", comment: ""), error.localizedDescription), virtualMachine: vm)
            }
        }
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

    override func shouldPerformSegue(withIdentifier identifier: NSStoryboardSegue.Identifier, sender _: Any?) -> Bool {
        if identifier == MacMulatorConstants.CONVERT_VM_SEGUE {
            if #available(macOS 14.0, *) {
                return true
            } else {
                return false
            }
        }
        return true
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == MacMulatorConstants.SHOW_VM_VIEW_SEGUE {
            let source = segue.sourceController as! VirtualMachineViewController
            let dest = segue.destinationController as! VirtualMachineContainerViewController
            let vmToStart = sender as! VMToStart

            if let runner = vmToStart.runner {
                dest.setVirtualMachine(vmToStart.vm)
                dest.setRecoveryMode(vmToStart.inRecovery)
                dest.setVmRunner(runner)
                dest.setVmController(source)
                dest.setVmRunner(rootController?.getRunnerForCurrentVM() as! VirtualizationFrameworkVirtualMachineRunner)
                dest.setSession(vmToStart.session)
            }
        } else if segue.identifier == MacMulatorConstants.SHOW_SPICE_VIEW_SEGUE {
            let source = segue.sourceController as! VirtualMachineViewController
            let dest = segue.destinationController as! QemuSpiceViewerViewController
            let vmToStart = sender as! VMToStart

            if let runner = vmToStart.runner {
                dest.setVirtualMachine(vmToStart.vm)
                dest.setRecoveryMode(vmToStart.inRecovery)
                dest.setVmRunner(runner)
                dest.setVmController(source)
                dest.setVmRunner(rootController?.getRunnerForCurrentVM() as! QemuRunner)
                dest.setMouseCaptureEnabled(Utils.getCaptureMouseForSubType(vmToStart.vm.type ?? "", vmToStart.vm.subtype))
                dest.setSession(vmToStart.session)
                spiceViewer = dest
            }
        } else if segue.identifier == MacMulatorConstants.START_VM_SEGUE {
            let source = segue.sourceController as! VirtualMachineViewController
            let dest = segue.destinationController as! StartVMViewController
            let vmToStart = sender as! VMToStart

            if let runner = vmToStart.runner {
                dest.setVmRunner(runner)
                dest.setVirtualMachine(vmToStart.vm)
                dest.setRecoveryMode(vmToStart.inRecovery)
                dest.setVmController(source)
            }
        } else if segue.identifier == MacMulatorConstants.CONVERT_VM_SEGUE {
            if #available(macOS 13.0, *), let rootController, let currentVM = rootController.currentVm {
                let source = segue.sourceController as! VirtualMachineViewController
                let dest = segue.destinationController as! ConvertVMViewController

                dest.setOperation(sender as! ConversionOperations)
                dest.setVirtualMachine(currentVM)
                dest.setParentController(source)
            }
        } else if segue.identifier == MacMulatorConstants.SHOW_CLONE_VIEW_SEGUE {
            let source = segue.sourceController as! VirtualMachineViewController
            let dest = segue.destinationController as! CloneVMViewController
            let vmToClone = sender as! VMToStart

            dest.setVirtualMachine(vmToClone.vm)
            dest.setParentController(source)
        }
    }

    func cleanupStoppedVM(_ vm: VirtualMachine) {
        TerminalSessionWindowController.closeSessions(on: vm)
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

            if let rootController, let currentVm = rootController.currentVm {
                if Utils.isVMTemplate(currentVm) {
                    startVMButton.isEnabled = false
                    pauseVMButton.isEnabled = false
                } else if !QemuUtils.isBinaryAvailable(currentVm.architecture, currentVm.qemuPath) {
                    startVMButton.isEnabled = false
                } else if Utils.isPauseSupported(currentVm) {
                    pauseVMButton.isEnabled = true
                    pauseVMButton.toolTip = NSLocalizedString("VirtualMachineViewController.pauseVM", comment: "")
                } else {
                    pauseVMButton.isEnabled = false
                    pauseVMButton.toolTip = NSLocalizedString("VirtualMachineViewController.pauseNotSupported", comment: "")
                }
            }
        } else {
            showNoVmsLayout()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCentralBoxConstraints()
        NotificationCenter.default.addObserver(self, selector: #selector(vmPauseStateChanged(_:)), name: MacMulatorConstants.VM_PAUSE_STATE_CHANGED_NOTIFICATION, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setVirtualMachine(_ virtualMachine: VirtualMachine?) {
        if let vm = virtualMachine {
            let backgroundImageName = Utils.getIconForSubType(vm.os, vm.subtype) + ".large"
            if Utils.isVMTemplate(vm) {
                if let newImage = Utils.getIconWithOverlay(backgroundImageName, "template.overlay.large") {
                    vmIcon.image = newImage
                }
            } else {
                vmIcon.image = NSImage(named: NSImage.Name(backgroundImageName))
            }

            if let rootController {
                if rootController.isVMPaused(vm) {
                    vmName.stringValue = String(format: NSLocalizedString("VirtualMachineViewController.pausedVMName", comment: ""), vm.displayName)
                } else if Utils.isVMTemplate(vm) {
                    vmName.stringValue = "VM Template - " + vm.displayName
                } else {
                    vmName.stringValue = vm.displayName
                }
            }

            vmDescription.stringValue = vm.description
            vmArchitecture.stringValue = QemuConstants.ALL_ARCHITECTURES_DESC[vm.architecture] ?? NSLocalizedString("VirtualMachineViewController.notSpecified", comment: "")
            vmType.stringValue = vm.subtype
            vmProcessors.intValue = Int32(vm.cpus)
            vmMemory.stringValue = Utils.formatMemory(vm.memory)

            vmHardDrive.stringValue = vm.type == MacMulatorConstants.APPLE_VM ? "Apple" : "QEMU"
            showVMAvailableLayout()

            if rootController?.getRunnerForRunningVM(vm) != nil {
                setRunningStatus(vm, true)
            } else {
                setRunningStatus(vm, false)
            }

            if Utils.isVMTemplate(vm) {
                startVMButton.isEnabled = false
                qemuUnavailableLabel.stringValue = "VM template cannot be started"
                qemuUnavailableLabel.isHidden = false
            } else if vm.type == nil || vm.type == MacMulatorConstants.QEMU_VM {
                if Utils.isVMAvailable(vm) {
                    startVMButton.isEnabled = true
                    qemuUnavailableLabel.isHidden = true
                } else if vm.subtype == QemuConstants.SUB_WINDOWS_11, QemuCapabilitiesReporter.getInstance(forQemuPath: QemuUtils.getQemuPath(for: vm))?.hasSwtpmBinary == false {
                    startVMButton.isEnabled = false
                    qemuUnavailableLabel.stringValue = String(format: NSLocalizedString("VirtualMachineViewController.swTpmNotAvailable", comment: ""), vmArchitecture.stringValue)
                    qemuUnavailableLabel.isHidden = false
                } else {
                    startVMButton.isEnabled = false
                    qemuUnavailableLabel.stringValue = String(format: NSLocalizedString("VirtualMachineViewController.binaryNotAvaiable", comment: ""), vm.architecture)
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

    @objc private func vmPauseStateChanged(_ notification: Notification) {
        let changedVM = notification.object as? VirtualMachine
        if changedVM != rootController?.currentVm || rootController?.isCurrentVMRunning() == true {
            return
        }

        DispatchQueue.main.async {
            self.setVirtualMachine(self.rootController?.currentVm)
        }
    }

    func setRunningStatus(_ vm: VirtualMachine?, _ running: Bool) {
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

                if rootController.isVMPaused(vm), screenshotExists {
                    vmName.stringValue = String(format: NSLocalizedString("VirtualMachineViewController.pausedVMName", comment: ""), vm.displayName)

                    resizeCentralBox(true)
                    hideBoxControls(true)

                    centralBox.title = NSLocalizedString("VirtualMachineViewController.vmPaused", comment: "")
                    let imagefile = NSImage(contentsOfFile: vm.path + "/" + MacMulatorConstants.SCREENSHOT_FILE_NAME)
                    if let image = imagefile {
                        let imageView = NSImageView(image: image)
                        // Let the box size drive the image, not the screenshot's intrinsic size
                        imageView.imageScaling = .scaleProportionallyUpOrDown
                        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
                        screenshotView = imageView
                        centralBox.contentView = imageView
                    }
                    bottomConfigureVMButton.isHidden = false
                } else if Utils.isVMTemplate(vm) {
                    vmName.stringValue = vm.displayName + " (VM template)"

                    // TODO: style UI
                    resizeCentralBox(false)
                    hideBoxControls(false)

                    centralBox.contentView = boxContentView
                    bottomConfigureVMButton.isHidden = true
                    updateHeadlessView(vm, running)
                } else {
                    vmName.stringValue = vm.displayName

                    resizeCentralBox(false)
                    hideBoxControls(false)

                    centralBox.contentView = boxContentView
                    bottomConfigureVMButton.isHidden = true
                    updateHeadlessView(vm, running)
                }
            }
        }
    }

    /// For headless VMs, replaces the VM details in the central box (all but the icon and the configure button) with the headless view, whose
    /// session buttons follow the session items of the VM menu
    fileprivate func updateHeadlessView(_ vm: VirtualMachine, _ running: Bool) {
        guard Utils.isHeadless(vm), let boxContentView else {
            headlessView.removeFromSuperview()
            hideVMDetails(false)
            return
        }

        hideVMDetails(true)
        if headlessView.superview !== boxContentView {
            headlessView.removeFromSuperview()
            headlessView.translatesAutoresizingMaskIntoConstraints = false
            boxContentView.addSubview(headlessView)
            NSLayoutConstraint.activate([
                headlessView.leadingAnchor.constraint(equalTo: vmIcon.trailingAnchor, constant: 21),
                boxContentView.trailingAnchor.constraint(equalTo: headlessView.trailingAnchor, constant: 20),
                headlessView.topAnchor.constraint(equalTo: vmIcon.topAnchor),
                // Keep clear of the configure button, which stays at the bottom of the box
                editVMButton.topAnchor.constraint(greaterThanOrEqualTo: headlessView.bottomAnchor, constant: 12),
            ])
        }

        headlessLabel.stringValue = NSLocalizedString("VirtualMachineViewController.headlessVM", comment: "")
        sshSessionButton.title = NSLocalizedString("AppDelegate.openSSHSession", comment: "")
        terminalSessionButton.title = NSLocalizedString("AppDelegate.openTerminalSession", comment: "")

        let actions = VMSessionActions(vm: vm, isRunning: running)
        screenSessionButton.title = actions.screenTitle
        for (button, action) in [(screenSessionButton, actions.screen), (sshSessionButton, actions.ssh), (terminalSessionButton, actions.terminal)] {
            button?.isHidden = action.isHidden
            button?.isEnabled = action.isEnabled
            // Tooltips are shown on disabled buttons too: tell why the session cannot be opened
            button?.toolTip = action.disabledReason
        }
    }

    fileprivate func setupCentralBoxConstraints() {
        guard let container = centralBox.superview else { return }

        // The storyboard defines fixed width/height constraints on the box: reuse them, so that they
        // are not left as required constraints preventing the box from growing
        let sizeConstraints = centralBox.constraints.filter { $0.firstItem === centralBox && $0.secondItem == nil && $0.relation == .equal }
        if centralBoxWidth == nil {
            centralBoxWidth = sizeConstraints.first { $0.firstAttribute == .width } ?? centralBox.widthAnchor.constraint(equalToConstant: 468)
        }
        if centralBoxHeight == nil {
            centralBoxHeight = sizeConstraints.first { $0.firstAttribute == .height } ?? centralBox.heightAnchor.constraint(equalToConstant: 210)
        }
        if centralBoxLeadingSpace == nil {
            centralBoxLeadingSpace = centralBox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 56)
        }
        if centralBoxTrailingSpace == nil {
            centralBoxTrailingSpace = container.trailingAnchor.constraint(equalTo: centralBox.trailingAnchor, constant: 56)
        }
        if centralBoxBottomSpace == nil {
            centralBoxBottomSpace = bottomConfigureVMButton.topAnchor.constraint(equalTo: centralBox.bottomAnchor, constant: 20)
        }

        let constraints = [centralBoxWidth, centralBoxHeight, centralBoxLeadingSpace, centralBoxTrailingSpace, centralBoxBottomSpace].compactMap(\.self)
        for constraint in constraints {
            // Priority cannot be changed between required and optional while a constraint is active
            constraint.isActive = false
            constraint.priority = .defaultLow
            constraint.isActive = true
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
        editVMButton.isHidden = hidden
        hideVMDetails(hidden)
    }

    /// Hides the VM details shown next to the icon in the central box
    fileprivate func hideVMDetails(_ hidden: Bool) {
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
    }

    private lazy var loadingView: NSStackView = {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.isIndeterminate = true
        spinner.controlSize = .regular
        spinner.startAnimation(nil)
        let label = NSTextField(labelWithString: NSLocalizedString("VirtualMachineViewController.loadingVMs", comment: ""))
        label.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [spinner, label])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return stack
    }()

    fileprivate func showLoadingLayout() {
        noVMsBox.removeFromSuperview()
        vmName.isHidden = true
        vmDescription.isHidden = true
        centralBox.isHidden = true
        startVMButton.isHidden = true
        stopVMButton.isHidden = true
        pauseVMButton.isHidden = true
        qemuUnavailableLabel.isHidden = true
        loadingView.isHidden = false
        bottomConfigureVMButton.isHidden = true
    }

    fileprivate func showNoVmsLayout() {
        if (NSApp.delegate as? AppDelegate)?.initialized == false {
            showLoadingLayout()
            return
        }
        loadingView.isHidden = true
        attachNoVMsBox()

        vmName.isHidden = true
        vmDescription.isHidden = true
        centralBox.isHidden = true
        startVMButton.isHidden = true
        qemuUnavailableLabel.isHidden = true

        noVMWelcomeMessage.stringValue = NSLocalizedString("VirtualMachineViewController.noVMWelcomeMessage", comment: "")
        newVMLabel.title = NSLocalizedString("VirtualMachineViewController.newVMLabel", comment: "")
        importVMLabel.title = NSLocalizedString("VirtualMachineViewController.importVMLabel", comment: "")
        bottomConfigureVMButton.isHidden = true
    }

    /// The no VMs box is a top level view of the scene, attached to the main view only while there are no VMs
    fileprivate func attachNoVMsBox() {
        guard let container = centralBox.superview, noVMsBox.superview !== container else { return }

        noVMsBox.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(noVMsBox)
        NSLayoutConstraint.activate([
            noVMsBox.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            noVMsBox.topAnchor.constraint(equalTo: container.topAnchor, constant: 52),
            startVMButton.topAnchor.constraint(equalTo: noVMsBox.bottomAnchor, constant: 3),
        ])
    }

    fileprivate func showVMAvailableLayout() {
        loadingView.isHidden = true
        noVMsBox.removeFromSuperview()

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
        vmHardDriveDesc.stringValue = NSLocalizedString("VirtualMachineViewController.vmEngine", comment: "")
        editVMButton.title = NSLocalizedString("VirtualMachineViewController.editVMButton", comment: "")
    }

    func startVMPrerequisitesCompleted(_ runner: any VirtualMachineRunner, _ inRecovery: Bool, _ vm: VirtualMachine) {
        startVM_internal(runner, inRecovery, vm)
        if !Utils.isHeadless(vm), QemuUtils.isSpiceDisplayEnabled(vm) {
            performSegue(withIdentifier: MacMulatorConstants.SHOW_SPICE_VIEW_SEGUE, sender: VMToStart(vm: vm, inRecovery: inRecovery, runner: runner))
        }
    }

    fileprivate func startVM_internal(_ runner: any VirtualMachineRunner, _ inRecovery: Bool, _ vm: VirtualMachine) {
        do {
            if vm.subtype == QemuConstants.SUB_WINDOWS_11 {
                let swTpmPath = QemuUtils.getQemuPath(for: vm)
                let shell = Shell()
                shell.runCommand(Utils.escape(swTpmPath) + "/swtpm socket --tpmstate dir=" + Utils.escape(vm.path) + "/tpm  --ctrl type=unixio,path=" + Utils.escape(QemuUtils.tpmSocketPath(forVMAt: vm.path)) + "  --log level=20 --tpm2", vm.path, uponCompletion: { _, _ in
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

                rootController.setRunningVM(vm, runner)
                setRunningStatus(vm, true)

                if vm.bootMode == nil {
                    vm.bootMode = Utils.getBootModeForSubType(vm.os, vm.subtype)
                    vm.writeToPlist()
                }

                if vm.type == MacMulatorConstants.APPLE_VM, canStartHeadless(vm) {
                    startHeadlessAppleVM(runner as! VirtualizationFrameworkVirtualMachineRunner, inRecovery)
                } else if vm.type == MacMulatorConstants.APPLE_VM {
                    performSegue(withIdentifier: MacMulatorConstants.SHOW_VM_VIEW_SEGUE, sender: VMToStart(vm: vm, inRecovery: inRecovery, runner: runner))
                } else if vm.bootMode == QemuConstants.BOOT_UEFI || vm.bootMode == QemuConstants.BOOT_UEFI_SECURE || (vm.os == QemuConstants.OS_MAC && vm.architecture == QemuConstants.ARCH_X64) {
                    performSegue(withIdentifier: MacMulatorConstants.START_VM_SEGUE, sender: VMToStart(vm: vm, inRecovery: inRecovery, runner: runner))
                } else if !Utils.isHeadless(vm), QemuUtils.isSpiceDisplayEnabled(vm) {
                    startVM_internal(runner, inRecovery, vm)
                    performSegue(withIdentifier: MacMulatorConstants.SHOW_SPICE_VIEW_SEGUE, sender: VMToStart(vm: vm, inRecovery: inRecovery, runner: runner))
                } else {
                    startVM_internal(runner, inRecovery, vm)
                }
            }
        }
    }

    /// Apple VMs run headless only once their OS is installed: the installation progress is shown in the VM window
    fileprivate func canStartHeadless(_ vm: VirtualMachine) -> Bool {
        guard Utils.isHeadless(vm) else { return false }
        if Utils.isMacVMWithOSVirtualizationFramework(os: vm.os, subtype: vm.subtype) {
            return Utils.findMainDrive(vm.drives)?.isBlank() == false
        }
        return true
    }

    /// Starts an Apple VM with no VM window. Its screen can be shown later with openScreenSession()
    fileprivate func startHeadlessAppleVM(_ runner: VirtualizationFrameworkVirtualMachineRunner, _ inRecovery: Bool) {
        runner.setVmController(self)
        runner.runVM(recoveryMode: inRecovery, uponCompletion: { _, _ in })
    }

    /// Shows the screen of the current (running, headless) VM: in the VM window for Apple VMs, in a Spice viewer for
    /// Qemu VMs. Closing the window leaves the VM running
    func openScreenSession() {
        guard let rootController, let vm = rootController.currentVm, let runner = rootController.getRunnerForRunningVM(vm) else { return }

        let existingWindow = NSApp.windows.first { window in
            (window.contentViewController as? RunningVMManagerViewController)?.virtualMachine == vm
        }
        if let existingWindow {
            existingWindow.makeKeyAndOrderFront(self)
            return
        }
        let segue = vm.type == MacMulatorConstants.APPLE_VM ? MacMulatorConstants.SHOW_VM_VIEW_SEGUE : MacMulatorConstants.SHOW_SPICE_VIEW_SEGUE
        performSegue(withIdentifier: segue, sender: VMToStart(vm: vm, inRecovery: false, runner: runner, session: true))
    }

    /// Opens a MacMulator terminal window on an SSH connection to the current VM, through the port mapped onto the guest SSH port
    func openSSHSession() {
        guard let vm = rootController?.currentVm, !TerminalSessionWindowController.bringExistingToFront(.ssh, vm) else { return }

        if vm.type != MacMulatorConstants.APPLE_VM, QemuUtils.sshPortMapping(for: vm) == nil {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.warning, message: NSLocalizedString("VirtualMachineViewController.noSshPortMapping", comment: ""), virtualMachine: vm)
            return
        }
        askSSHUserName(for: vm) {
            if vm.type == MacMulatorConstants.APPLE_VM {
                self.openSSHSessionOnAppleVM(vm)
            } else if let args = QemuUtils.sshArguments(for: vm) {
                TerminalSessionWindowController.open(.ssh, on: vm, executable: "/usr/bin/ssh", args: args)
            }
        }
    }

    /// Asks the user to log in as, suggesting the last one used for the VM (or the provisioned one, or the Mac user),
    /// and remembers it in the VM
    fileprivate func askSSHUserName(for vm: VirtualMachine, then connect: @escaping () -> Void) {
        let alert = NSAlert()
        alert.icon = NSImage(named: NSImage.Name(Utils.getIconForSubType(vm.os, vm.subtype) + ".small"))
        alert.messageText = String(format: NSLocalizedString("VirtualMachineViewController.sshUserNamePrompt", comment: ""), vm.displayName)

        let userNameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        userNameField.stringValue = Utils.guestUserName(vm) ?? NSUserName()
        alert.accessoryView = userNameField
        alert.addButton(withTitle: NSLocalizedString("VirtualMachineViewController.sshConnect", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Utils.calcel", comment: ""))
        alert.window.initialFirstResponder = userNameField

        alert.beginSheetModal(for: view.window!) { response in
            let userName = userNameField.stringValue.trimmingCharacters(in: .whitespaces)
            guard response == .alertFirstButtonReturn, !userName.isEmpty else { return }

            if vm.guestUserName != userName {
                vm.guestUserName = userName
                vm.writeToPlist()
            }
            connect()
        }
    }

    /// Apple VMs get their own IP address (from the macOS DHCP server, or the LAN when bridged): look it up from the MAC
    /// address. The terminal window opens at once, with a spinner, and is usable when the address is known
    fileprivate func openSSHSessionOnAppleVM(_ vm: VirtualMachine) {
        guard let macAddress = vm.macAddress, let window = view.window else { return }

        let session = TerminalSessionWindowController.openPending(.ssh, on: vm)
        DispatchQueue.global(qos: .userInitiated).async {
            let ipAddress = GuestNetworkLookup.ipAddress(forMACAddress: macAddress)
            DispatchQueue.main.async {
                guard let ipAddress else {
                    session.cancel()
                    Utils.showAlert(window: window, style: NSAlert.Style.warning, message: NSLocalizedString("VirtualMachineViewController.guestIPAddressNotFound", comment: ""), virtualMachine: vm)
                    return
                }
                var destination = ipAddress
                if let userName = Utils.guestUserName(vm) {
                    destination = userName + "@" + destination
                }
                // Keep the spinner a little longer: the guest may have only just started its SSH server
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    session.start(executable: "/usr/bin/ssh", args: Utils.sshArguments(for: vm, destination: destination), banner: "ssh " + destination)
                }
            }
        }
    }

    /// Opens a MacMulator terminal window on the serial console of the current VM
    func openTerminalSession() {
        guard let vm = rootController?.currentVm else { return }

        if vm.type == MacMulatorConstants.APPLE_VM {
            if let serialConsole = (rootController?.getRunnerForRunningVM(vm) as? VirtualizationFrameworkVirtualMachineRunner)?.serialConsole {
                TerminalSessionWindowController.open(serialConsole, on: vm)
            }
            return
        }

        guard !TerminalSessionWindowController.bringExistingToFront(.serialConsole, vm) else { return }

        guard let serialConsole = QemuSerialConsole(socketPath: QemuUtils.serialSocketPath(forVMAt: vm.path)) else {
            Utils.showAlert(window: view.window!, style: NSAlert.Style.warning, message: NSLocalizedString("VirtualMachineViewController.serialConsoleNotAvailable", comment: ""), virtualMachine: vm)
            return
        }
        TerminalSessionWindowController.open(serialConsole, on: vm)
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
                                self.closeSpiceWindowAndShowAlert(result: result, virtualMachine: virtualMachine)
                            }
                        })
                    }
                }
            }

            if result.exitCode != 0 {
                self.closeSpiceWindowAndShowAlert(result: result, virtualMachine: virtualMachine)
            }
        }
    }

    fileprivate func closeSpiceWindowAndShowAlert(result: VMExecutionResult, virtualMachine: VirtualMachine) {
        if let spiceViewer, spiceViewer.virtualMachine == virtualMachine {
            spiceViewer.closeWindow()
            self.spiceViewer = nil
        }
        Utils.showAlert(window: view.window!, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("VirtualMachineViewController.vmExecutionFailed", comment: ""), result.error?.localizedCapitalized ?? NSLocalizedString("VirtualMachineViewController.notSpecified", comment: "")), virtualMachine: virtualMachine)
    }
}
