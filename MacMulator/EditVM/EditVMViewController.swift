//
//  EditVMViewController.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

enum AllowedEditsWhileLocked: String {
    case nothing = ""
    case nameAndDescription = "NameAndDescription"
    case usbImages = "USBImages"
}

protocol VMSettingsLockable: AnyObject {
    var allowedEditsWhileLocked: AllowedEditsWhileLocked { get }
    func setVMLocked(_ locked: Bool)
}

extension VMSettingsLockable {
    var allowedEditsWhileLocked: AllowedEditsWhileLocked {
        .nothing
    }
}

class EditVMViewController: NSTabViewController {
    var vmRunner: VirtualMachineRunner?
    var virtualMachine: VirtualMachine?
    private let lockedNoticeLabel = NSTextField(wrappingLabelWithString: "")
    private lazy var lockedNotice = makeLockedNotice()
    private var vmPaused = false
    private var vmLocked = false

    func setVmRunner(_ vmRunner: VirtualMachineRunner) {
        self.vmRunner = vmRunner
    }

    func setVirtualMachine(_ vm: VirtualMachine) {
        view.window?.title = String(format: NSLocalizedString("EditVMViewController.windowTitle", comment: ""), vm.displayName)

        virtualMachine = vm

        tabViewItems[0].label = NSLocalizedString("EditVMViewController.general", comment: "")
        tabViewItems[1].label = NSLocalizedString("EditVMViewController.hardware", comment: "")
        tabViewItems[2].label = NSLocalizedString("EditVMViewController.network", comment: "")
        tabViewItems[3].label = NSLocalizedString("EditVMViewController.network", comment: "")
        tabViewItems[4].label = NSLocalizedString("EditVMViewController.video", comment: "")
        tabViewItems[5].label = NSLocalizedString("EditVMViewController.snapshots", comment: "")
        tabViewItems[6].label = NSLocalizedString("EditVMViewController.cloudInit", comment: "")
        tabViewItems[7].label = NSLocalizedString("EditVMViewController.advanced", comment: "")

        let general = tabViewItems[0].viewController as! EditVMViewControllerGeneral
        let hardware = tabViewItems[1].viewController as! EditVMViewControllerHardware
        let network = tabViewItems[2].viewController as! EditVMViewControllerNetwork
        let networkVF = tabViewItems[3].viewController as! EditVMViewControllerNetworkVF
        let video = tabViewItems[4].viewController as! EditVMViewControllerVideo
        let snapshots = tabViewItems[5].viewController as! EditVMViewControllerSnapshots
        let cloudInit = tabViewItems[6].viewController as! EditVMViewControllerCloudInit
        let advanced = tabViewItems[7].viewController as! EditVMViewControllerAdvanced

        general.setVirtualMachine(vm)
        hardware.setVirtualMachine(vm)
        network.setVirtualMachine(vm)
        networkVF.setVirtualMachine(vm)
        video.setVirtualMachine(vm)
        snapshots.setVirtualMachine(vm)
        cloudInit.setVirtualMachine(vm)
        advanced.setVirtualMachine(vm)

        if let vmRunner {
            hardware.setVmRunner(vmRunner)
            snapshots.setVmRunner(vmRunner)
        }

        let cloudInitSupported = Utils.isCloudInitSupported(vm)
        if vm.type == MacMulatorConstants.APPLE_TEMPLATE_VM {
            removeTabViewItem(tabViewItems[7])
            removeTabViewItem(tabViewItems[6])
            removeTabViewItem(tabViewItems[5])
            removeTabViewItem(tabViewItems[4])
            removeTabViewItem(tabViewItems[2])
        } else if vm.type == MacMulatorConstants.APPLE_VM {
            removeTabViewItem(tabViewItems[7])
            if !cloudInitSupported {
                removeTabViewItem(tabViewItems[6])
            }
            removeTabViewItem(tabViewItems[2])
        } else if vm.type == MacMulatorConstants.QEMU_TEMPLATE_VM {
            removeTabViewItem(tabViewItems[7])
            removeTabViewItem(tabViewItems[6])
            removeTabViewItem(tabViewItems[5])
            removeTabViewItem(tabViewItems[3])
        } else {
            if !cloudInitSupported {
                removeTabViewItem(tabViewItems[6])
            }
            removeTabViewItem(tabViewItems[3])
        }

        updateLockState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(vmStateChanged(_:)), name: MacMulatorConstants.VM_RUN_STATE_CHANGED_NOTIFICATION, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(vmStateChanged(_:)), name: MacMulatorConstants.VM_PAUSE_STATE_CHANGED_NOTIFICATION, object: nil)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window, !window.titlebarAccessoryViewControllers.contains(lockedNotice) {
            window.addTitlebarAccessoryViewController(lockedNotice)
        }
        updateLockState()
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        updateLockedNotice()
    }

    override func viewWillDisappear() {
        virtualMachine?.writeToPlist()
    }

    override func viewDidDisappear() {
        if let virtualMachine {
            virtualMachine.writeToPlist()
            // The folder of the VM follows its name.
            (NSApp.delegate as? AppDelegate)?.rootController?.renameVMFolderToMatchName(virtualMachine)
        }
    }

    func selectTab(tabIdentifier: String) {
        guard let idx = tabViewItems.firstIndex(where: { ($0.identifier as? String) == tabIdentifier }) else { return }
        selectedTabViewItemIndex = idx
    }

    @objc private func vmStateChanged(_ notification: Notification) {
        guard let changedVM = notification.object as? VirtualMachine, changedVM === virtualMachine else { return }
        DispatchQueue.main.async {
            self.updateLockState()
        }
    }

    private func updateLockState() {
        guard let virtualMachine, let rootController = (NSApp.delegate as? AppDelegate)?.rootController else { return }

        let running = rootController.isVMRunning(virtualMachine)
        let paused = rootController.isVMPaused(virtualMachine)
        // The VM may have been started or stopped since the panel was opened
        let runner = rootController.getRunnerForRunningVM(virtualMachine) ?? Utils.createDummyRunnerForStoppedVM(virtualMachine)
        vmRunner = runner

        for item in tabViewItems {
            if let hardware = item.viewController as? EditVMViewControllerHardware {
                hardware.setVmRunner(runner)
            } else if let snapshots = item.viewController as? EditVMViewControllerSnapshots {
                snapshots.setVmRunner(runner)
            }
            (item.viewController as? VMSettingsLockable)?.setVMLocked(running || paused)
        }

        vmPaused = paused
        vmLocked = running || paused
        updateLockedNotice()
    }

    private func updateLockedNotice() {
        let selectedController = tabViewItems.indices.contains(selectedTabViewItemIndex) ? tabViewItems[selectedTabViewItemIndex].viewController : nil
        // Tabs that lock nothing, like Snapshots, show no notice
        guard vmLocked, let lockable = selectedController as? VMSettingsLockable else {
            lockedNotice.isHidden = true
            return
        }

        let key = (vmPaused ? "EditVMViewController.vmPausedNotice" : "EditVMViewController.vmRunningNotice") + lockable.allowedEditsWhileLocked.rawValue
        lockedNoticeLabel.stringValue = NSLocalizedString(key, comment: "")
        lockedNotice.isHidden = false
    }

    private func makeLockedNotice() -> NSTitlebarAccessoryViewController {
        let icon = NSImageView(image: NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .secondaryLabelColor
        icon.setContentHuggingPriority(.required, for: .horizontal)
        lockedNoticeLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [icon, lockedNoticeLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 20, bottom: 6, right: 20)
        stack.frame = NSRect(x: 0, y: 0, width: 600, height: 30)

        let controller = NSTitlebarAccessoryViewController()
        controller.view = stack
        controller.layoutAttribute = .bottom
        controller.isHidden = true
        return controller
    }
}
