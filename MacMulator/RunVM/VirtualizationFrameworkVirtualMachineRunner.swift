//
//  VirtualizationFrameworkVirtualMachineRunner.swift
//  MacMulator
//
//  Created by Vale on 14/04/22.
//

import Foundation
import Virtualization

@available(macOS 12.0, *)
class VirtualizationFrameworkVirtualMachineRunner: NSObject, VirtualMachineRunner, VZVirtualMachineDelegate {
    let managedVm: VirtualMachine
    let saveFileURL: URL
    let screenshotFileURL: URL
    var vzVirtualMachine: VZVirtualMachine?
    var passthroughDevices: [UInt64: AnyObject] = [:]
    var pendingPassthroughIDs: Set<UInt64> = []
    var vmView: VZVirtualMachineView?
    var vmViewController: VirtualMachineContainerViewController?
    /// The main view controller, which is told when a headless VM (one with no VM window) stops
    weak var vmController: VirtualMachineViewController?
    var recoveryMode: Bool = false
    /// The serial console of Linux VMs, which Terminal sessions connect to
    private(set) var serialConsole: VirtualizationFrameworkSerialConsole?

    init(virtualMachine: VirtualMachine) {
        managedVm = virtualMachine
        saveFileURL = URL(fileURLWithPath: managedVm.path).appendingPathComponent(MacMulatorConstants.SAVE_FILE_NAME)
        screenshotFileURL = URL(fileURLWithPath: managedVm.path).appendingPathComponent(MacMulatorConstants.SCREENSHOT_FILE_NAME)
    }

    func getManagedVM() -> VirtualMachine {
        managedVm
    }

    func setVmView(_ vmView: VZVirtualMachineView) {
        self.vmView = vmView
    }

    func setVmViewController(_ vmViewController: VirtualMachineContainerViewController) {
        self.vmViewController = vmViewController
    }

    func setVmController(_ vmController: VirtualMachineViewController) {
        self.vmController = vmController
    }

    /// The window alerts are shown on: the VM window, or the main window when the VM runs headless
    private var alertWindow: NSWindow {
        if let window = vmView?.window {
            return window
        }
        // Headless: nothing else shows that something went wrong, so bring the main window to the front
        let mainWindow = (NSApp.delegate as! AppDelegate).rootController!.view.window!
        mainWindow.makeKeyAndOrderFront(nil)
        return mainWindow
    }

    /// Shows the running VM in `view`, owned by the VM window `viewController` (opened as a session on a headless VM)
    func attachView(_ view: VZVirtualMachineView, _ viewController: VirtualMachineContainerViewController) {
        vmView = view
        vmViewController = viewController
        configureVmView()
    }

    /// Forgets the VM window, once it is closed: the VM keeps running headless
    func detachView() {
        vmView?.virtualMachine = nil
        vmView = nil
        vmViewController = nil
    }

    private func configureVmView() {
        vmView?.virtualMachine = vzVirtualMachine
        if #available(macOS 14.0, *) {
            vmView?.automaticallyReconfiguresDisplay = true
        }
        vmView?.capturesSystemKeys = true
    }

    func runVM(recoveryMode: Bool, uponCompletion _: @escaping (VMExecutionResult, VirtualMachine) -> Void) {
        self.recoveryMode = recoveryMode

        if managedVm.macAddress == nil {
            // Keep the same MAC address across runs: the IP address of the guest is looked up through it (see GuestNetworkLookup)
            managedVm.macAddress = VZMACAddress.randomLocallyAdministered().string
            managedVm.writeToPlist()
        }

        if Utils.isMacVMWithOSVirtualizationFramework(os: managedVm.os, subtype: managedVm.subtype) {
            #if arch(arm64)

                vzVirtualMachine = VirtualizationFrameworkMacOSSupport.decodeMacOSVirtualMachine(vm: managedVm)

                let isDriveBlank = Utils.findMainDrive(managedVm.drives)!.isBlank()
                if isDriveBlank {
                    installAndStartVM()
                } else {
                    startOrResumeVM()
                }

            #endif
        } else if #available(macOS 13.0, *) {
            let installMedia = Utils.findUSBInstallDrive(managedVm.drives)
            var installPath: String? = nil
            if let installMedia {
                installPath = installMedia.path
            } else {
                installPath = ""
            }
            let console = VirtualizationFrameworkSerialConsole()
            serialConsole = console
            vzVirtualMachine = VirtualizationFrameworkLinuxSupport.decodeLinuxVirtualMachine(vm: managedVm, installMedia: installPath!, serialPort: console.makePortConfiguration())
            startOrResumeVM()
        }
    }

    func instllationComplete(_ result: Result<Void, Error>) {
        if case let .failure(error) = result {
            Utils.showAlert(window: alertWindow, style: NSAlert.Style.critical, message: "Installation failed with error: " + error.localizedDescription, virtualMachine: managedVm)
        } else {
            Utils.findMainDrive(managedVm.drives)!.setBlank(blank: false)
            managedVm.writeToPlist()
            startVM()
        }
    }

    func guestDidStop(_: VZVirtualMachine) {
        print("Stopped")
        stopVM(guestStopped: true)
    }

    func isVMRunning() -> Bool {
        vzVirtualMachine != nil && vzVirtualMachine!.state == VZVirtualMachine.State.running
    }

    func startVM() {
        if let vzVirtualMachine {
            vzVirtualMachine.delegate = self
            configureVmView()
            if #available(macOS 13.0, *), Utils.isMacVMWithOSVirtualizationFramework(os: managedVm.os, subtype: managedVm.subtype) {
                #if arch(arm64)
                    let options = VZMacOSVirtualMachineStartOptions()
                    options.startUpFromMacOSRecovery = self.recoveryMode
                    if #available(macOS 27.0, *), let provisioningInfo = managedVm.provisioningInformation {
                        let guestProvisioning = VZMacGuestProvisioningOptions()
                        guestProvisioning.fullName = provisioningInfo.userFullName
                        guestProvisioning.username = provisioningInfo.userName
                        guestProvisioning.password = provisioningInfo.userPassword
                        guestProvisioning.enablesRemoteLogin = provisioningInfo.enableSSh
                        guestProvisioning.logsInAutomatically = provisioningInfo.automaticLogin
                        do {
                            try options.setGuestProvisioning(guestProvisioning)
                        } catch {
                            Utils.showAlert(window: alertWindow, style: NSAlert.Style.critical, message: String(format: NSLocalizedString("VirtualizationFrameworkVirtualMachineRunner.provisioningFailed", comment: ""), error.localizedDescription), virtualMachine: managedVm)
                            return
                        }
                    }
                    vzVirtualMachine.start(options: options, completionHandler: { result in self.handleVMStartWithOptions(error: result) })
                #endif
            } else {
                vzVirtualMachine.start(completionHandler: { result in self.handleVMStart(result: result) })
            }
        }
    }

    func createVMSnapshot(_ underlyingHandler: ((VirtualMachineSnapshot?) -> Void)? = nil) throws {
        if #available(macOS 14.0, *), isVMRunning(), Utils.isPauseSupported(managedVm) {
            #if arch(arm64)
                vmViewController?.takeScreenshot()
                vmViewController?.showSnapshottingView()
                pauseAndSaveVirtualMachine(completionHandler: {
                    let snapshot = try? self.copyVMSnapshotFiles(running: true, managedVm: self.managedVm)
                    self.resumeVM()
                    if let underlyingHandler {
                        underlyingHandler(snapshot)
                    }
                })
            #endif
        } else {
            if isVMRunning() {
                throw ValidationError.snapshotError(vmType: "Intel")
            }

            let snapshot = try? copyVMSnapshotFiles(running: false, managedVm: managedVm)
            if let underlyingHandler {
                underlyingHandler(snapshot)
            }
        }
    }

    func deleteVMSnapshot(snapshot: VirtualMachineSnapshot) throws {
        managedVm.removeSnapshot(snapshot.timestamp)
        try deleteVMSnapshotFiles(snapshot: snapshot, managedVm: managedVm)
    }

    func restoreVMSnapshot(snapshot: VirtualMachineSnapshot, _ underlyingHandler: ((VirtualMachineSnapshot?) -> Void)? = nil) throws {
        if #available(macOS 14.0, *), isVMRunning(), Utils.isPauseSupported(managedVm) {
            #if arch(arm64)
                vmViewController?.showRestoringView()
                stopVM(guestStopped: false, uponCompletion: { _ in
                    try? self.restoreVMSnapshotFiles(snapshot: snapshot, managedVm: self.managedVm)
                    self.vzVirtualMachine?.restoreMachineStateFrom(url: self.saveFileURL, completionHandler: { error in
                        let fileManager = FileManager.default
                        try? fileManager.removeItem(at: self.saveFileURL)

                        if error == nil {
                            self.resumeVM()
                        } else {
                            self.startVM()
                        }
                    })
                    if let underlyingHandler {
                        underlyingHandler(snapshot)
                    }
                })
            #endif
        } else {
            if isVMRunning() {
                throw ValidationError.snapshotError(vmType: "Intel")
            }

            try? restoreVMSnapshotFiles(snapshot: snapshot, managedVm: managedVm)
            if let underlyingHandler {
                underlyingHandler(snapshot)
            }
        }
    }

    fileprivate func handleVMStartWithOptions(error: (any Error)?) {
        if error != nil {
            Utils.showAlert(window: alertWindow, style: NSAlert.Style.critical, message: "Virtual machine failed to start \(error)", completionHandler: { _ in self.stopVM(guestStopped: true) }, virtualMachine: nil)
        } else {
            if let provisioningInformation = managedVm.provisioningInformation {
                // The user name is still needed to open SSH sessions on the VM
                managedVm.guestUserName = provisioningInformation.userName
                provisioningInformation.cleanup()
                managedVm.provisioningInformation = nil
                managedVm.writeToPlist()
            }
            attachUSBDrives()
        }
    }

    fileprivate func handleVMStart(result: Result<Void, any Error>) {
        switch result {
        case let .failure(error):
            Utils.showAlert(window: alertWindow, style: NSAlert.Style.critical, message: "Virtual machine failed to start \(error)", completionHandler: { _ in self.stopVM(guestStopped: true) }, virtualMachine: nil)
        default:
            attachUSBDrives()
        }
    }

    fileprivate func attachUSBDrives() {
        attachUSBPassthroughDevices()
        if #available(macOS 15.0, *) {
            for drive in self.managedVm.drives {
                if drive.mediaType == QemuConstants.MEDIATYPE_USB {
                    self.attachUSBImageToVM(virtualDrive: drive)
                }
            }
        }
    }

    fileprivate func attachUSBPassthroughDevices() {
        if #available(macOS 27.0, *) {
            #if arch(arm64)
                for controller in vzVirtualMachine?.usbControllers ?? [] {
                    controller.delegate = self
                }
                reattachSavedPassthroughDevices()
            #endif
        }
    }

    @available(macOS 14.0, *)
    func resumeVM() {
        if let vzVirtualMachine {
            vzVirtualMachine.delegate = self
            configureVmView()
            vzVirtualMachine.resume(completionHandler: { result in
                if case let .failure(error) = result {
                    Utils.showAlert(window: self.alertWindow, style: NSAlert.Style.critical, message: "Virtual machine failed to resume \(error)", completionHandler: { _ in self.stopVM(guestStopped: true) }, virtualMachine: self.managedVm)
                } else {
                    // Passthrough devices are not part of the saved machine state: plug back the ones saved for this VM
                    self.attachUSBPassthroughDevices()
                }
                NSLog(String(vzVirtualMachine.state.rawValue))
            })
        }
    }

    func stopVM(guestStopped: Bool, uponCompletion: (((any Error)?) -> Void)?) {
        if #available(macOS 27.0, *) {
            releasePassthroughDevices()
        }
        if let uponCompletion {
            vzVirtualMachine?.stop(completionHandler: uponCompletion)
        } else {
            vzVirtualMachine?.stop(completionHandler: { _ in })
        }
        if let vmViewController {
            vmViewController.stopVM(guestStopped)
        } else {
            // Headless: there is no VM window to clean up after the VM
            DispatchQueue.main.async {
                self.vmController?.cleanupStoppedVM(self.managedVm)
            }
        }
    }

    func stopVMGracefully() {
        do {
            try vzVirtualMachine?.requestStop()
        } catch {
            stopVM(guestStopped: false)
        }
        vmViewController?.stopVM(false)
    }

    func pauseVM() {
        if #available(macOS 14.0, *) {
            if let vzVirtualMachine = self.vzVirtualMachine {
                if vzVirtualMachine.state == .running {
                    vmViewController?.takeScreenshot()
                    vmViewController?.showPausingView()
                    #if arch(arm64)
                        if #available(macOS 27.0, *) {
                            detachPassthroughDevicesBeforeSaving {
                                self.pauseAndSaveVirtualMachine(completionHandler: {
                                    self.stopVM(guestStopped: true)
                                })
                            }
                        } else {
                            self.pauseAndSaveVirtualMachine(completionHandler: {
                                self.stopVM(guestStopped: true)
                            })
                        }
                    #endif
                }
            }
        }
    }

    func abort() {
        vmViewController?.view.window?.close()
    }

    func getConsoleOutput() -> String {
        ""
    }

    fileprivate func startOrResumeVM() {
        if #available(macOS 14.0, *) {
            #if arch(arm64)
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: saveFileURL.path) {
                    restoreVirtualMachine()
                } else {
                    startVM()
                }
            #else
                startVM()
            #endif
        } else {
            startVM()
        }
    }

    fileprivate func installAndStartVM() {
        vmViewController?.performSegue(withIdentifier: MacMulatorConstants.SHOW_INSTALLING_OS_SEGUE, sender: self)
    }

    #if arch(arm64)

        @available(macOS 14.0, *)
        fileprivate func restoreVirtualMachine() {
            vmViewController?.showResumingView()
            vzVirtualMachine?.restoreMachineStateFrom(url: saveFileURL, completionHandler: { error in
                let fileManager = FileManager.default
                try? fileManager.removeItem(at: self.saveFileURL)
                try? fileManager.removeItem(at: URL(fileURLWithPath: self.managedVm.path + "/" + MacMulatorConstants.SCREENSHOT_FILE_NAME))

                if error == nil {
                    self.resumeVM()
                } else {
                    self.startVM()
                }

                (self.vmViewController?.vmController ?? self.vmController)?.setRunningStatus(self.managedVm, true)
            })
        }

        @available(macOS 14.0, *)
        func saveVirtualMachine(completionHandler: @escaping () -> Void) {
            vzVirtualMachine?.saveMachineStateTo(url: saveFileURL, completionHandler: { error in
                guard error == nil else {
                    fatalError("Virtual machine failed to save with \(error!)")
                }

                completionHandler()
            })
        }

        @available(macOS 14.0, *)
        func pauseAndSaveVirtualMachine(completionHandler: @escaping () -> Void) {
            vzVirtualMachine?.pause(completionHandler: { result in
                if case let .failure(error) = result {
                    fatalError("Virtual machine failed to pause with \(error)")
                }

                self.saveVirtualMachine(completionHandler: completionHandler)
            })
        }

    #endif

    @available(macOS 15.0, *)
    func attachUSBImageToVM(virtualDrive: VirtualDrive) {
        let diskURL = URL(fileURLWithPath: virtualDrive.path)
        do {
            let diskAttachment = try VZDiskImageStorageDeviceAttachment(url: diskURL, readOnly: false)
            let usbMassStorageDeviceConfiguration = VZUSBMassStorageDeviceConfiguration(attachment: diskAttachment)
            let usbMassStorageDevice = VZUSBMassStorageDevice(configuration: usbMassStorageDeviceConfiguration)

            if let usbControllers = vzVirtualMachine?.usbControllers, usbControllers.count > 0 {
                vzVirtualMachine?.usbControllers[0].attach(device: usbMassStorageDevice, completionHandler: { _ in
                    print("Image at path " + virtualDrive.path + " attached.")
                })
            }
            virtualDrive.vzDeviceUUID = usbMassStorageDevice.uuid.uuidString
            managedVm.writeToPlist()
        } catch {
            Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.critical, message: error.localizedDescription, virtualMachine: managedVm)
        }
    }

    @available(macOS 15.0, *)
    func detachUSBImageFromVM(virtualDrive: VirtualDrive) {
        if let usbControllers = vzVirtualMachine?.usbControllers, usbControllers.count > 0 {
            for device in usbControllers[0].usbDevices {
                if device.uuid.uuidString == virtualDrive.vzDeviceUUID {
                    usbControllers[0].detach(device: device, completionHandler: { _ in
                        print("Image at path " + virtualDrive.path + " detached.")
                    })
                }
            }
        }
    }

    @available(macOS 27.0, *)
    func passthroughAccessoryRemoved(registryID: UInt64) {
        #if arch(arm64)
            guard let device = passthroughDevices.removeValue(forKey: registryID) as? VZUSBPassthroughDevice else { return }
            vzVirtualMachine?.usbControllers.first?.detach(device: device) { _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: UsbPassthroughManager.didChangeNotification, object: nil)
                }
            }
        #endif
    }

    @available(macOS 27.0, *)
    func releasePassthroughDevices() {
        #if arch(arm64)
            let registryIDs = Array(passthroughDevices.keys)
            passthroughDevices.removeAll()
            for registryID in registryIDs {
                guard let accessory = UsbPassthroughManager.shared.accessory(withRegistryID: registryID) else { continue }
                accessory.close { error in
                    if let error {
                        NSLog("USB passthrough release failed: %@", String(describing: error))
                    }
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: UsbPassthroughManager.didChangeNotification, object: nil)
                    }
                }
            }
        #endif
    }

    @available(macOS 27.0, *)
    func detachPassthroughDevicesBeforeSaving(completionHandler: @escaping () -> Void) {
        #if arch(arm64)
            guard let usbController = vzVirtualMachine?.usbControllers.first else {
                completionHandler()
                return
            }
            let group = DispatchGroup()
            for device in passthroughDevices.values.compactMap({ $0 as? VZUSBPassthroughDevice }) {
                group.enter()
                usbController.detach(device: device) { error in
                    if let error {
                        NSLog("USB passthrough detach before saving failed: %@", String(describing: error))
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main, execute: completionHandler)
        #endif
    }

    @available(macOS 27.0, *)
    func reattachSavedPassthroughDevices() {
        #if arch(arm64)
            guard let saved = managedVm.usbPassthroughDevices, !saved.isEmpty else { return }
            NSLog("USB passthrough: restoring saved devices %@", saved.joined(separator: ","))
            UsbPassthroughManager.shared.start(retryAfterFailure: true) {
                DispatchQueue.main.async {
                    self.restoreSavedPassthroughDevices()
                }
            }
        #endif
    }

    @available(macOS 27.0, *)
    func restoreSavedPassthroughDevices() {
        #if arch(arm64)
            guard isVMRunning(), let saved = managedVm.usbPassthroughDevices, !saved.isEmpty else { return }
            let candidates = UsbPassthroughManager.shared.candidates()
            var remaining = candidates.filter { !isPassthroughAttached(registryID: $0.registryID) && !pendingPassthroughIDs.contains($0.registryID) }
            var missing = saved
            for candidate in candidates where isPassthroughAttached(registryID: candidate.registryID) || pendingPassthroughIDs.contains(candidate.registryID) {
                if let index = missing.firstIndex(of: candidate.key) {
                    missing.remove(at: index)
                }
            }
            for key in missing {
                guard let index = remaining.firstIndex(where: { $0.key == key }) else { continue }
                let candidate = remaining.remove(at: index)
                attachPassthroughDevice(registryID: candidate.registryID, silent: true)
            }
        #endif
    }

    @available(macOS 27.0, *)
    func isPassthroughAttached(registryID: UInt64) -> Bool {
        #if arch(arm64)
            guard let device = passthroughDevices[registryID] as? VZUSBPassthroughDevice else { return false }
            let stillAttached = vzVirtualMachine?.usbControllers.first?.usbDevices.contains { $0.uuid == device.uuid } ?? false
            if !stillAttached {
                passthroughDevices.removeValue(forKey: registryID)
            }
            return stillAttached
        #else
            return false
        #endif
    }

    @available(macOS 27.0, *)
    func attachPassthroughDevice(registryID: UInt64, silent: Bool = false) {
        #if arch(arm64)
            guard passthroughDevices[registryID] == nil, !pendingPassthroughIDs.contains(registryID),
                  let accessory = UsbPassthroughManager.shared.accessory(withRegistryID: registryID),
                  let usbController = vzVirtualMachine?.usbControllers.first else { return }
            do {
                let device = try VZUSBPassthroughDevice(configuration: VZUSBPassthroughDeviceConfiguration(device: accessory))
                pendingPassthroughIDs.insert(registryID)
                usbController.attach(device: device) { error in
                    DispatchQueue.main.async {
                        self.pendingPassthroughIDs.remove(registryID)
                        if let error {
                            NSLog("USB passthrough attach failed: %@", String(describing: error))
                            if !silent {
                                Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.critical, message: error.localizedDescription, virtualMachine: nil)
                            }
                        } else {
                            self.passthroughDevices[registryID] = device
                            NotificationCenter.default.post(name: UsbPassthroughManager.didChangeNotification, object: nil)
                        }
                    }
                }
            } catch {
                Utils.showAlert(window: NSApp.mainWindow!, style: NSAlert.Style.critical, message: error.localizedDescription, virtualMachine: nil)
            }
        #endif
    }

    @available(macOS 27.0, *)
    func detachPassthroughDevice(registryID: UInt64) {
        #if arch(arm64)
            guard let device = passthroughDevices[registryID] as? VZUSBPassthroughDevice, let usbController = vzVirtualMachine?.usbControllers.first else { return }
            usbController.detach(device: device) { _ in
                DispatchQueue.main.async {
                    self.passthroughDevices.removeValue(forKey: registryID)
                    NotificationCenter.default.post(name: UsbPassthroughManager.didChangeNotification, object: nil)
                }
            }
        #endif
    }
}

#if arch(arm64)
    @available(macOS 27.0, *)
    extension VirtualizationFrameworkVirtualMachineRunner: VZUSBController.Delegate {
        func usbController(_: VZUSBController, usbPassthroughDeviceDidDisconnect device: VZUSBPassthroughDevice) {
            DispatchQueue.main.async {
                for (registryID, attached) in self.passthroughDevices {
                    if let attached = attached as? VZUSBPassthroughDevice, attached.uuid == device.uuid {
                        self.passthroughDevices.removeValue(forKey: registryID)
                    }
                }
                NotificationCenter.default.post(name: UsbPassthroughManager.didChangeNotification, object: nil)
            }
        }
    }
#endif
