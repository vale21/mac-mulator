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
    var vmView: VZVirtualMachineView?
    var vmViewController: VirtualMachineContainerViewController?
    var recoveryMode: Bool = false

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

    func runVM(recoveryMode: Bool, uponCompletion _: @escaping (VMExecutionResult, VirtualMachine) -> Void) {
        self.recoveryMode = recoveryMode

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
            vzVirtualMachine = VirtualizationFrameworkLinuxSupport.decodeLinuxVirtualMachine(vm: managedVm, installMedia: installPath!)
            startOrResumeVM()
        }
    }

    func instllationComplete(_ result: Result<Void, Error>) {
        if case let .failure(error) = result {
            Utils.showAlert(window: vmView!.window!, style: NSAlert.Style.critical, message: "Installation failed with error: " + error.localizedDescription, virtualMachine: managedVm)
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
            vmView?.virtualMachine = vzVirtualMachine
            if #available(macOS 14.0, *) {
                self.vmView?.automaticallyReconfiguresDisplay = true
            }
            vmView?.capturesSystemKeys = true
            if #available(macOS 13.0, *), Utils.isMacVMWithOSVirtualizationFramework(os: managedVm.os, subtype: managedVm.subtype) {
                #if arch(arm64)
                    let options = VZMacOSVirtualMachineStartOptions()
                    options.startUpFromMacOSRecovery = self.recoveryMode
                    vzVirtualMachine.start(options: options, completionHandler: { result in self.handleVMStartWithOptions(error: result) })
                #endif
            } else {
                vzVirtualMachine.start(completionHandler: { result in self.handleVMStart(result: result) })
            }
        }
    }

    func createVMSnapshot(_ underlyingHandler: ((VirtualMachineSnapshot?) -> Void)? = nil) throws {
        if #available(macOS 14.0, *), isVMRunning() {
            #if arch(arm64)
                vmViewController?.takeScreenshot()
                vmViewController?.showSnapshottingView()
                pauseAndSaveVirtualMachine(completionHandler: {
                    let snapshot = try? self.copyVMSnapshotFiles(running: true)
                    self.resumeVM()
                    if let underlyingHandler {
                        underlyingHandler(snapshot)
                    }
                })
            #else
                let snapshot = try? self.copyVMSnapshotFiles(running: false)
                if let underlyingHandler {
                    underlyingHandler(snapshot)
                }
            #endif
        } else {
            let snapshot = try? copyVMSnapshotFiles(running: false)
            if let underlyingHandler {
                underlyingHandler(snapshot)
            }
        }
    }

    func deleteVMSnapshot(snapshot: VirtualMachineSnapshot) throws {
        managedVm.removeSnapshot(snapshot.timestamp)
        try deleteVMSnapshotFiles(snapshot: snapshot)
    }

    func restoreVMSnapshot(snapshot: VirtualMachineSnapshot, _ underlyingHandler: ((VirtualMachineSnapshot?) -> Void)? = nil) throws {
        if #available(macOS 14.0, *), isVMRunning() {
            #if arch(arm64)
                vmViewController?.showRestoringView()
                stopVM(guestStopped: false, uponCompletion: { _ in
                    try? self.restoreVMSnapshotFiles(snapshot: snapshot)
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
            #else
                try? self.restoreVMSnapshotFiles(snapshot: snapshot)
                if let underlyingHandler {
                    underlyingHandler(snapshot)
                }
            #endif
        } else {
            try? restoreVMSnapshotFiles(snapshot: snapshot)
            if let underlyingHandler {
                underlyingHandler(snapshot)
            }
        }
    }

    fileprivate func copyVMSnapshotFiles(running: Bool) throws -> VirtualMachineSnapshot {
        let currentMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let snapshotsFolderPath = URL(fileURLWithPath: managedVm.path + "/Snapshots")
        let currentSnapshotFolderPath = snapshotsFolderPath.appendingPathComponent(String(currentMillis))

        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: currentSnapshotFolderPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("Snapshot: failed to create directory \(currentSnapshotFolderPath.path): \(error.localizedDescription)")
        }

        if fileManager.fileExists(atPath: saveFileURL.path) {
            let memorySnapshotURL = currentSnapshotFolderPath.appendingPathComponent(MacMulatorConstants.SAVE_FILE_NAME)
            do {
                try fileManager.moveItem(at: URL(fileURLWithPath: saveFileURL.path), to: memorySnapshotURL)
            } catch {
                NSLog("Snapshot: failed to move memory save file from \(saveFileURL.path) to \(memorySnapshotURL.path): \(error.localizedDescription)")
                throw error
            }
        }

        if fileManager.fileExists(atPath: screenshotFileURL.path) {
            let screenshotSnapshotURL = currentSnapshotFolderPath.appendingPathComponent(MacMulatorConstants.SCREENSHOT_FILE_NAME)
            do {
                try fileManager.moveItem(at: URL(fileURLWithPath: screenshotFileURL.path), to: screenshotSnapshotURL)
            } catch {
                NSLog("Snapshot: failed to move screenshot from \(screenshotFileURL.path) to \(screenshotSnapshotURL.path): \(error.localizedDescription)")
                throw error
            }
        }

        var drivePaths: [String] = []
        for drive in managedVm.drives {
            if drive.mediaType == QemuConstants.MEDIATYPE_DISK || drive.mediaType == QemuConstants.MEDIATYPE_NVME {
                let driveSnapshotURL = currentSnapshotFolderPath.appendingPathComponent(drive.name + "." + MacMulatorConstants.DISK_EXTENSION)
                do {
                    try fileManager.copyItem(at: URL(fileURLWithPath: drive.path), to: driveSnapshotURL)
                } catch {
                    NSLog("Snapshot: failed to copy drive \(drive.name) from \(drive.path) to \(driveSnapshotURL.path): \(error.localizedDescription)")
                    throw error
                }
                drivePaths.append(driveSnapshotURL.path)
            }
        }
        if managedVm.snapshots == nil {
            managedVm.snapshots = []
        }

        let snapshot = VirtualMachineSnapshot(timestamp: currentMillis,
                                              name: "",
                                              description: "This snapsot was taken on " + Date().formatted(),
                                              driveSnapshotPaths: drivePaths,
                                              memorySnapshotPath: running ? currentSnapshotFolderPath.appendingPathComponent(MacMulatorConstants.SAVE_FILE_NAME).path : nil,
                                              screenshotPath: running ? currentSnapshotFolderPath.appendingPathComponent(MacMulatorConstants.SCREENSHOT_FILE_NAME).path : nil,
                                              running: running)
        managedVm.snapshots!.append(snapshot)
        managedVm.writeToPlist()
        return snapshot
    }

    fileprivate func deleteVMSnapshotFiles(snapshot: VirtualMachineSnapshot) throws {
        let fileManager = FileManager.default

        var filePaths: [String] = snapshot.driveSnapshotPaths
        if let memorySnapshotPath = snapshot.memorySnapshotPath {
            filePaths.append(memorySnapshotPath)
        }
        if let screenshotPath = snapshot.screenshotPath {
            filePaths.append(screenshotPath)
        }

        for filePath in filePaths where fileManager.fileExists(atPath: filePath) {
            do {
                try fileManager.removeItem(atPath: filePath)
            } catch {
                NSLog("Snapshot: failed to delete file \(filePath): \(error.localizedDescription)")
                throw error
            }
        }

        let snapshotFolderURL = URL(fileURLWithPath: managedVm.path)
            .appendingPathComponent("Snapshots")
            .appendingPathComponent(String(snapshot.timestamp))
        if fileManager.fileExists(atPath: snapshotFolderURL.path) {
            do {
                try fileManager.removeItem(at: snapshotFolderURL)
            } catch {
                NSLog("Snapshot: failed to delete folder \(snapshotFolderURL.path): \(error.localizedDescription)")
                throw error
            }
        }
    }

    fileprivate func restoreVMSnapshotFiles(snapshot: VirtualMachineSnapshot) throws {
        let fileManager = FileManager.default

        if let memorySnapshotPath = snapshot.memorySnapshotPath {
            do {
                try? fileManager.removeItem(at: URL(fileURLWithPath: saveFileURL.path))
                try fileManager.copyItem(at: URL(fileURLWithPath: memorySnapshotPath), to: URL(fileURLWithPath: saveFileURL.path))
            } catch {
                NSLog("Snapshot: failed to move save file \(memorySnapshotPath): \(error.localizedDescription)")
            }
        }
        if let screenshotPath = snapshot.screenshotPath {
            do {
                try? fileManager.removeItem(at: URL(fileURLWithPath: screenshotFileURL.path))
                try fileManager.copyItem(at: URL(fileURLWithPath: screenshotPath), to: URL(fileURLWithPath: screenshotFileURL.path))
            } catch {
                NSLog("Snapshot: failed to move save file \(screenshotPath): \(error.localizedDescription)")
            }
        }
        for drivePath in snapshot.driveSnapshotPaths {
            do {
                let destDrivePath = URL(fileURLWithPath: managedVm.path).appendingPathComponent(URL(fileURLWithPath: drivePath).lastPathComponent)
                try fileManager.removeItem(at: destDrivePath)
                try fileManager.copyItem(at: URL(fileURLWithPath: drivePath), to: destDrivePath)
            } catch {
                NSLog("Snapshot: failed to move disk file \(drivePath): \(error.localizedDescription)")
            }
        }
    }

    fileprivate func handleVMStartWithOptions(error: (any Error)?) {
        if error != nil {
            Utils.showAlert(window: (vmView?.window)!, style: NSAlert.Style.critical, message: "Virtual machine failed to start \(error)", completionHandler: { _ in self.stopVM(guestStopped: true) }, virtualMachine: nil)
        } else {
            attachUSBDrives()
        }
    }

    fileprivate func handleVMStart(result: Result<Void, any Error>) {
        switch result {
        case let .failure(error):
            Utils.showAlert(window: (vmView?.window)!, style: NSAlert.Style.critical, message: "Virtual machine failed to start \(error)", completionHandler: { _ in self.stopVM(guestStopped: true) }, virtualMachine: nil)
        default:
            attachUSBDrives()
        }
    }

    fileprivate func attachUSBDrives() {
        if #available(macOS 15.0, *) {
            for drive in self.managedVm.drives {
                if drive.mediaType == QemuConstants.MEDIATYPE_USB {
                    self.attachUSBImageToVM(virtualDrive: drive)
                }
            }
        }
    }

    @available(macOS 14.0, *)
    func resumeVM() {
        if let vzVirtualMachine {
            vzVirtualMachine.delegate = self
            vmView?.virtualMachine = vzVirtualMachine
            vmView?.automaticallyReconfiguresDisplay = true
            vmView?.capturesSystemKeys = true

            vzVirtualMachine.resume(completionHandler: { result in
                if case let .failure(error) = result {
                    Utils.showAlert(window: (self.vmView?.window)!, style: NSAlert.Style.critical, message: "Virtual machine failed to resume \(error)", completionHandler: { _ in self.stopVM(guestStopped: true) }, virtualMachine: self.managedVm)
                }
                NSLog(String(vzVirtualMachine.state.rawValue))
            })
        }
    }

    func stopVM(guestStopped: Bool, uponCompletion: (((any Error)?) -> Void)?) {
        if let uponCompletion {
            vzVirtualMachine?.stop(completionHandler: uponCompletion)
        } else {
            vzVirtualMachine?.stop(completionHandler: { _ in })
        }
        vmViewController?.stopVM(guestStopped)
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
                        pauseAndSaveVirtualMachine(completionHandler: {
                            self.stopVM(guestStopped: true)
                        })
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
}
