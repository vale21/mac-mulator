//
//  EditVMViewControllerHardware.swift
//  MacMulator
//
//  Created by Vale on 12/02/21.
//

import Cocoa

class EditVMViewControllerHardware: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet var architectureLabel: NSTextField!
    @IBOutlet var architectureComboBox: NSComboBox!
    @IBOutlet var cpusLabel: NSTextField!
    @IBOutlet var cpusComboBox: NSComboBox!
    @IBOutlet var memoryLabel: NSTextField!
    @IBOutlet var memoryTextView: NSTextField!
    @IBOutlet var memoryStepper: NSStepper!
    @IBOutlet var memorySlider: NSSlider!
    @IBOutlet var minMemoryLabel: NSTextField!
    @IBOutlet var maxMemoryLabel: NSTextField!
    @IBOutlet var drivesTableLabel: NSTextField!
    @IBOutlet var drivesTableView: NSTableView!
    @IBOutlet var openImageButton: NSButton!
    @IBOutlet var createNewDiskButton: NSButton!
    @IBOutlet var importDriveButton: NSButton!

    var virtualMachine: VirtualMachine?
    var vmRunner: VirtualMachineRunner?

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        updateView()
    }

    func setVmRunner(_ vmRunner: VirtualMachineRunner) {
        self.vmRunner = vmRunner
    }

    @IBAction func sliderChanged(_ sender: Any) {
        if sender as? NSObject == memorySlider {
            if let virtualMachine {
                virtualMachine.memory = memorySlider.intValue
                memoryTextView.stringValue = String(virtualMachine.memory)
                memoryStepper.intValue = virtualMachine.memory
            }
        }
    }

    @IBAction func stepperChanged(_ sender: Any) {
        if sender as? NSObject == memoryStepper {
            if let virtualMachine {
                virtualMachine.memory = memoryStepper.intValue
                memoryTextView.stringValue = String(virtualMachine.memory)
                memorySlider.intValue = virtualMachine.memory
            }
        }
    }

    @IBAction func openImage(_: Any) {
        Utils.showFileSelector(fileTypes: Utils.IMAGE_TYPES, uponSelection: { panel in
            if let path = panel.url?.path {
                if let virtualMachine = self.virtualMachine {
                    for virtualDrive in virtualMachine.drives {
                        if virtualDrive.path == path {
                            Utils.showAlert(window: self.view.window!, style: NSAlert.Style.informational, message: String(format: NSLocalizedString("EditVMViewControllerHardware.imageAlreadyLoaded", comment: ""), path), virtualMachine: virtualMachine)
                            return
                        }
                    }

                    // no existing drive found
                    var newDrive: VirtualDrive
                    if path.hasSuffix(QemuConstants.FORMAT_QCOW2) || path.hasSuffix(MacMulatorConstants.DISK_EXTENSION) {
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_DISK + "-" + String(Utils.computeNextDriveIndex(virtualMachine, QemuConstants.MEDIATYPE_DISK)),
                            format: QemuConstants.FORMAT_UNKNOWN,
                            mediaType: QemuConstants.MEDIATYPE_DISK,
                            size: 0
                        )
                    } else if path.hasSuffix(MacMulatorConstants.EFI_EXTENSION) {
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_EFI + "-" + String(Utils.computeNextDriveIndex(virtualMachine, QemuConstants.MEDIATYPE_EFI)),
                            format: QemuConstants.FORMAT_RAW,
                            mediaType: QemuConstants.MEDIATYPE_EFI,
                            size: 0
                        )
                    } else if path.hasSuffix(MacMulatorConstants.IPSW_EXTENSION) {
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_IPSW + "-0",
                            format: QemuConstants.FORMAT_RAW,
                            mediaType: QemuConstants.MEDIATYPE_IPSW,
                            size: 0
                        )
                    } else if virtualMachine.type == MacMulatorConstants.APPLE_VM {
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_USB + "-0",
                            format: QemuConstants.FORMAT_RAW,
                            mediaType: QemuConstants.MEDIATYPE_USB,
                            size: 0
                        )

                        if #available(macOS 15.0, *), vmRunner?.isVMRunning() == true,
                           let vfRunner = vmRunner as? VirtualizationFrameworkVirtualMachineRunner
                        {
                            vfRunner.attachUSBImageToVM(virtualDrive: newDrive)
                        }
                    } else if virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_USB_CDROM + "-0",
                            format: QemuConstants.FORMAT_RAW,
                            mediaType: QemuConstants.MEDIATYPE_USB_CDROM,
                            size: 0
                        )
                    } else if virtualMachine.architecture == QemuConstants.ARCH_X64, virtualMachine.os == QemuConstants.OS_MAC {
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_USB + "-0",
                            format: QemuConstants.FORMAT_RAW,
                            mediaType: QemuConstants.MEDIATYPE_USB,
                            size: 0
                        )
                    } else {
                        newDrive = VirtualDrive(
                            path: path,
                            name: QemuConstants.MEDIATYPE_CDROM + "-" + String(Utils.computeNextDriveIndex(virtualMachine, QemuConstants.MEDIATYPE_CDROM)),
                            format: QemuConstants.FORMAT_RAW,
                            mediaType: QemuConstants.MEDIATYPE_CDROM,
                            size: 0
                        )
                    }
                    virtualMachine.addVirtualDrive(newDrive)
                    virtualMachine.writeToPlist()

                    updateView()
                }
            }
        })
    }

    @IBAction func importDrive(_: Any) {
        guard let virtualMachine else { return }
        Utils.showFileSelector(fileTypes: Utils.IMPORT_DRIVE_TYPES, uponSelection: { panel in
            guard let path = panel.url?.path else { return }
            DiskImageManagerFactory().create(forVM: virtualMachine).getDiskImageDetails(path, qemuPath: QemuUtils.getQemuPath(for: virtualMachine), uponCompletion: { details, errorMessage in
                DispatchQueue.main.async {
                    guard let details else {
                        Utils.showAlert(window: self.view.window!, style: .critical, message: String(format: NSLocalizedString("EditVMViewControllerHardware.importDriveUnreadable", comment: ""), (path as NSString).lastPathComponent, errorMessage ?? ""), virtualMachine: virtualMachine)
                        return
                    }
                    let fileName = (path as NSString).lastPathComponent
                    guard Utils.isDiskImageImportSupported(details, virtualMachine) else {
                        self.showImportNotSupported(fileName, details, virtualMachine)
                        return
                    }
                    if virtualMachine.type == MacMulatorConstants.APPLE_VM {
                        if details.format == QemuConstants.FORMAT_ASIF {
                            self.startDriveImport(path, details, targetFormat: QemuConstants.FORMAT_ASIF)
                            return
                        }
                        guard Utils.isAsifSupported(virtualMachine) else {
                            self.startDriveImport(path, details, targetFormat: QemuConstants.FORMAT_RAW)
                            return
                        }
                        self.askToConvert(message: String(format: NSLocalizedString("EditVMViewControllerHardware.importAsifImage", comment: ""), fileName),
                                          detail: NSLocalizedString("EditVMViewControllerHardware.importAsifImageDetail", comment: ""),
                                          convertTitle: NSLocalizedString("EditVMViewControllerHardware.importConvertToAsif", comment: ""),
                                          keepTitle: NSLocalizedString("EditVMViewControllerHardware.importUseRaw", comment: ""),
                                          completion: { convert in
                                              self.startDriveImport(path, details, targetFormat: convert ? QemuConstants.FORMAT_ASIF : QemuConstants.FORMAT_RAW)
                                          })
                    } else if details.format == QemuConstants.FORMAT_RAW, !Utils.isQemuImgSupported(virtualMachine) {
                        self.startDriveImport(path, details, targetFormat: QemuConstants.FORMAT_RAW)
                    } else if details.format == QemuConstants.FORMAT_RAW {
                        self.askToConvert(message: String(format: NSLocalizedString("EditVMViewControllerHardware.importRawImage", comment: ""), fileName),
                                          detail: NSLocalizedString("EditVMViewControllerHardware.importRawImageDetail", comment: ""),
                                          convertTitle: NSLocalizedString("EditVMViewControllerHardware.importConvertToQcow2", comment: ""),
                                          keepTitle: NSLocalizedString("EditVMViewControllerHardware.importKeepRaw", comment: ""),
                                          completion: { convert in
                                              self.startDriveImport(path, details, targetFormat: convert ? QemuConstants.FORMAT_QCOW2 : QemuConstants.FORMAT_RAW)
                                          })
                    } else {
                        self.startDriveImport(path, details, targetFormat: QemuConstants.FORMAT_QCOW2)
                    }
                }
            })
        })
    }

    @IBAction func deleteVirtualDrive(_ sender: Any) {
        if let virtualMachine {
            let row = drivesTableView.row(for: sender as! NSView)
            let index = Utils.computeDrivesTableIndex(virtualMachine, row)
            let drive = virtualMachine.drives[index]
            if drive.mediaType == QemuConstants.MEDIATYPE_CDROM || drive.mediaType == QemuConstants.MEDIATYPE_USB || drive.mediaType == QemuConstants.MEDIATYPE_USB_CDROM || drive.mediaType == QemuConstants.MEDIATYPE_IPSW {
                removeVirtualDrive(row, index)
            } else {
                Utils.showPrompt(window: view.window!, style: NSAlert.Style.informational, message: String(format: NSLocalizedString("EditVMViewControllerHardware.confirmDeleteDrive", comment: ""), drive.name), completionHandler: { response in
                    if response.rawValue == Utils.ALERT_RESP_OK {
                        self.removeVirtualDrive(row, index)
                        do {
                            try FileManager.default.removeItem(atPath: drive.path)
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                }, virtualMachine: virtualMachine)
            }
        }
    }

    override func viewWillAppear() {
        architectureLabel.stringValue = NSLocalizedString("EditVMViewControllerHardware.architectureLabel", comment: "")
        cpusLabel.stringValue = NSLocalizedString("EditVMViewControllerHardware.cpusLabel", comment: "")
        memoryLabel.stringValue = NSLocalizedString("EditVMViewControllerHardware.memoryLabel", comment: "")
        drivesTableLabel.stringValue = NSLocalizedString("EditVMViewControllerHardware.drivesTableLabel", comment: "")
        openImageButton.title = NSLocalizedString("EditVMViewControllerHardware.openImageButton", comment: "")
        createNewDiskButton.title = NSLocalizedString("EditVMViewControllerHardware.createNewDiskButton", comment: "")
        importDriveButton.title = NSLocalizedString("EditVMViewControllerHardware.importDriveButton", comment: "")

        for column in drivesTableView.tableColumns {
            if column.identifier.rawValue == "Name" {
                column.headerCell.title = NSLocalizedString("EditVMViewControllerHardware.drivesTableColumnName", comment: "")
            }
            if column.identifier.rawValue == "Type" {
                column.headerCell.title = NSLocalizedString("EditVMViewControllerHardware.drivesTableColumnType", comment: "")
            }
            if column.identifier.rawValue == "Size" {
                column.headerCell.title = NSLocalizedString("EditVMViewControllerHardware.drivesTableColumnSize", comment: "")
            }
            if column.identifier.rawValue == "Path" {
                column.headerCell.title = NSLocalizedString("EditVMViewControllerHardware.drivesTableColumnPath", comment: "")
            }
        }

        updateView()
    }

    override func shouldPerformSegue(withIdentifier identifier: NSStoryboardSegue.Identifier, sender _: Any?) -> Bool {
        if let virtualMachine {
            // This is bad, but it is the quckest way to differenciate the single iPod touch use case from all the others
            if identifier == MacMulatorConstants.NEW_DISK_SEGUE, virtualMachine.os == QemuConstants.OS_IOS {
                Utils.showDirectorySelector(uponSelection: { panel in
                    if let path = panel.url?.path {
                        virtualMachine.drives[0].path = path
                        updateView()
                    }
                })
                return false
            }
        }
        return true
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let virtualMachine {
            if segue.identifier == MacMulatorConstants.NEW_DISK_SEGUE {
                let mediaType = Utils.getMediaTypeForSubType(virtualMachine.os, virtualMachine.subtype)
                let diskName = mediaType + "-" + String(Utils.computeNextDriveIndex(virtualMachine, mediaType))

                var format = QemuConstants.FORMAT_RAW
                if virtualMachine.type == MacMulatorConstants.QEMU_VM {
                    format = QemuConstants.FORMAT_QCOW2
                } else if Utils.isAsifSupported(virtualMachine) {
                    format = QemuConstants.FORMAT_ASIF
                }
                let virtualDrive = VirtualDrive(path: virtualMachine.path, name: diskName, format: format, mediaType: mediaType, size: Int32(Utils.getDefaultDiskSizeForSubType(virtualMachine.os, virtualMachine.subtype)))

                let destinationController = segue.destinationController as! NewDiskViewController
                destinationController.setVirtualDrive(virtualDrive)
                destinationController.setparentController(self)
            }
            if segue.identifier == MacMulatorConstants.EDIT_DISK_SEGUE {
                let destinationController = segue.destinationController as! NewDiskViewController
                let driveTableRow: Int = drivesTableView.row(for: sender as! NSView)
                destinationController.setVirtualDrive(virtualMachine.drives[Utils.computeDrivesTableIndex(virtualMachine, driveTableRow)])
                destinationController.setparentController(self)
                destinationController.setMode(NewDiskViewController.Mode.EDIT)
            }
            if segue.identifier == MacMulatorConstants.SHOW_DRIVE_INFO_SEGUE {
                let destinationController = segue.destinationController as! NSWindowController
                let contentController = destinationController.contentViewController as! DriveInfoViewController
                let driveTableRow: Int = drivesTableView.row(for: sender as! NSView)
                contentController.isVirtualizaionFrameworkInUse = (virtualMachine.type == MacMulatorConstants.APPLE_VM || virtualMachine.type == MacMulatorConstants.APPLE_TEMPLATE_VM)
                contentController.setVirtualDrive(virtualMachine.drives[Utils.computeDrivesTableIndex(virtualMachine, driveTableRow)])
            }
        }
    }

    func numberOfItems(in comboBox: NSComboBox) -> Int {
        if comboBox == architectureComboBox {
            return QemuConstants.ALL_ARCHITECTURES_DESC.count
        } else {
            if let virtualMachine {
                return virtualMachine.os == QemuConstants.OS_IOS ? 1 : QemuConstants.MAX_CPUS[virtualMachine.architecture] ?? 0
            }
        }
        return 0
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if comboBox == architectureComboBox {
            return index >= 0 ? QemuConstants.ALL_ARCHITECTURES_DESC[QemuConstants.ALL_ARCHITECTURES[index]] : ""
        }
        return index + 1
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        if (notification.object as! NSComboBox) == architectureComboBox {
            if let virtualMachine {
                virtualMachine.architecture = QemuConstants.ALL_ARCHITECTURES[architectureComboBox.indexOfSelectedItem]

                cpusComboBox.reloadData()
                cpusComboBox.selectItem(at: virtualMachine.cpus - 1)
            }
        } else {
            if cpusComboBox.indexOfSelectedItem >= 0 {
                virtualMachine?.cpus = cpusComboBox.indexOfSelectedItem + 1
            } else {
                virtualMachine?.cpus = 1
            }
        }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if (notification.object as! NSTextField) == memoryTextView {
            if let virtualMachine {
                let mem = memoryTextView.stringValue
                let mem_num = Utils.toInt32WithAutoLocale(mem)
                if let memory = mem_num {
                    virtualMachine.memory = memory
                    memoryStepper.intValue = virtualMachine.memory
                    memorySlider.intValue = virtualMachine.memory

                    if memory < Utils.getMinMemoryForSubType(virtualMachine.os, virtualMachine.subtype) || memory > Utils.getMaxMemoryForSubType(virtualMachine.os, virtualMachine.subtype) {
                        memoryStepper.isEnabled = false
                        memorySlider.isEnabled = false
                    } else {
                        memoryStepper.isEnabled = true
                        memorySlider.isEnabled = true
                    }
                }
            }
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self)
        let index = Utils.computeDrivesTableIndex(virtualMachine, row)

        let drive = virtualMachine?.drives[index]

        if tableColumn?.identifier.rawValue == "Icon" {
            let cellView = cell as! DrivesTableIconCell

            if drive?.mediaType == QemuConstants.MEDIATYPE_DISK {
                cellView.icon.image = NSImage(named: "HD Icon")
            } else if drive?.mediaType == QemuConstants.MEDIATYPE_CDROM {
                cellView.icon.image = NSImage(named: "CD Icon")
            } else if drive?.mediaType == QemuConstants.MEDIATYPE_USB || drive?.mediaType == QemuConstants.MEDIATYPE_IPSW {
                cellView.icon.image = NSImage(named: "USB Icon")
            }
        }

        if tableColumn?.identifier.rawValue == "Name" {
            let cellView = cell as! DrivesTableDriveNameCell
            cellView.label.stringValue = drive?.name ?? ""
            cellView.toolTip = cellView.label.stringValue
        }

        if tableColumn?.identifier.rawValue == "Type" {
            let cellView = cell as! DrivesTableDriveTypeCell
            cellView.label.stringValue = QemuUtils.getDriveTypeDescription(drive?.mediaType ?? "")
            cellView.toolTip = cellView.label.stringValue
        }

        if tableColumn?.identifier.rawValue == "Size" {
            let cellView = cell as! DrivesTableDriveSizeCell
            cellView.label.stringValue = Utils.formatDisk(drive?.size ?? 0)
            cellView.toolTip = cellView.label.stringValue
        }

        if tableColumn?.identifier.rawValue == "Path" {
            let cellView = cell as! DrivesTableDrivePathCell
            cellView.label.stringValue = Utils.unescape(drive?.path ?? "")
            cellView.toolTip = cellView.label.stringValue
        }

        if tableColumn?.identifier.rawValue == "Buttons" {
            let cellView = cell as! DrivesTableButtonsCell
            if let virtualMachine, Utils.isVMTemplate(virtualMachine) {
                cellView.editButton.isEnabled = false
                cellView.deleteButton.isEnabled = false
            } else if drive?.mediaType == QemuConstants.MEDIATYPE_CDROM || drive?.mediaType == QemuConstants.MEDIATYPE_USB || drive?.mediaType == QemuConstants.MEDIATYPE_USB_CDROM || drive?.mediaType == QemuConstants.MEDIATYPE_IPSW || drive?.mediaType == QemuConstants.MEDIATYPE_NAND {
                cellView.editButton.isEnabled = false
            } else {
                cellView.editButton.isEnabled = true
            }
        }

        return cell
    }

    func numberOfRows(in _: NSTableView) -> Int {
        Utils.computeDrivesTableSize(virtualMachine)
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        30.0
    }

    func updateView() {
        if let virtualMachine {
            architectureComboBox.reloadData()
            architectureComboBox.selectItem(at: QemuConstants.ALL_ARCHITECTURES.firstIndex(of: virtualMachine.architecture) ?? -1)

            cpusComboBox.reloadData()
            cpusComboBox.selectItem(at: virtualMachine.cpus - 1)

            memoryStepper.intValue = virtualMachine.memory
            memorySlider.intValue = virtualMachine.memory
            memoryTextView.stringValue = String(virtualMachine.memory)

            let minMemory = Utils.getMinMemoryForSubType(virtualMachine.os, virtualMachine.subtype)
            let maxMemory = Utils.getMaxMemoryForSubType(virtualMachine.os, virtualMachine.subtype)

            minMemoryLabel.stringValue = Utils.formatMemory(Int32(minMemory))
            maxMemoryLabel.stringValue = Utils.formatMemory(Int32(maxMemory))
            memoryStepper.minValue = Double(minMemory)
            memoryStepper.maxValue = Double(maxMemory)
            memorySlider.minValue = Double(minMemory)
            memorySlider.maxValue = Double(maxMemory)

            if virtualMachine.memory < Utils.getMinMemoryForSubType(virtualMachine.os, virtualMachine.subtype) || virtualMachine.memory > Utils.getMaxMemoryForSubType(virtualMachine.os, virtualMachine.subtype) {
                memoryStepper.isEnabled = false
                memorySlider.isEnabled = false
            } else {
                memoryStepper.isEnabled = true
                memorySlider.isEnabled = true
            }

            drivesTableView.reloadData()

            if virtualMachine.os == QemuConstants.OS_IOS {
                createNewDiskButton.title = NSLocalizedString("EditVMViewControllerHardware.selectNandButton", comment: "")
            }
            updateDriveButtons(virtualMachine)

            let appDelegate = NSApp.delegate as! AppDelegate
            appDelegate.refreshVMMenus()
        }
    }

    func addVirtualDrive(_ virtualDrive: VirtualDrive) {
        virtualMachine?.drives.append(virtualDrive)
        updateView()
    }

    func reloadDrives() {
        drivesTableView.reloadData()
    }

    func driveImported(_ virtualDrive: VirtualDrive) {
        guard let virtualMachine else { return }
        virtualMachine.addVirtualDrive(virtualDrive)
        virtualMachine.writeToPlist()
        updateView()
    }

    func driveImportFailed(error: String) {
        Utils.showAlert(window: view.window!, style: .critical, message: String(format: NSLocalizedString("EditVMViewControllerHardware.importDriveFailed", comment: ""), error), virtualMachine: virtualMachine)
    }

    private func removeVirtualDrive(_ row: Int, _ index: Int) {
        if let virtualMachine {
            drivesTableView.removeRows(at: IndexSet(integer: IndexSet.Element(row)), withAnimation: NSTableView.AnimationOptions.slideUp)
            let removedDrive = virtualMachine.drives.remove(at: index)
            virtualMachine.writeToPlist()
            updateView()

            if #available(macOS 15.0, *), virtualMachine.type == MacMulatorConstants.APPLE_VM, vmRunner?.isVMRunning() == true,
               let vfRunner = vmRunner as? VirtualizationFrameworkVirtualMachineRunner
            {
                vfRunner.detachUSBImageFromVM(virtualDrive: removedDrive)

                let appDelegate = NSApp.delegate as! AppDelegate
                appDelegate.refreshVMMenus()
            }
        }
    }

    /// Enables the drive buttons, each with a tooltip saying what it does or why it is disabled.
    /// The rules are checked in order: the first matching one decides.
    private func updateDriveButtons(_ virtualMachine: VirtualMachine) {
        let isTemplate = Utils.isVMTemplate(virtualMachine)
        let isIOS = virtualMachine.os == QemuConstants.OS_IOS
        let isAppleVM = virtualMachine.type == MacMulatorConstants.APPLE_VM
        // Apple VMs have a single drive
        let hasAppleMainDrive = isAppleVM && Utils.findMainDrive(virtualMachine.drives) != nil

        let openImage: (enabled: Bool, tooltip: String) = if isTemplate {
            (false, "drivesTemplateTooltip")
        } else if isIOS {
            (false, "drivesIOSTooltip")
        } else if isAppleVM, Utils.findIPSWInstallDrive(virtualMachine.drives) != nil {
            (false, "openImageIPSWTooltip")
        } else {
            (true, "openImageTooltip")
        }

        let createNewDisk: (enabled: Bool, tooltip: String) = if isTemplate {
            (false, "drivesTemplateTooltip")
        } else if isIOS {
            // The button selects the NAND folder of the iPod touch
            (true, "selectNandTooltip")
        } else if hasAppleMainDrive {
            (false, "drivesOneDriveTooltip")
        } else {
            (true, "createNewDiskTooltip")
        }

        let importDrive: (enabled: Bool, tooltip: String) = if isTemplate {
            (false, "drivesTemplateTooltip")
        } else if isIOS {
            (false, "drivesIOSTooltip")
        } else if isAppleVM, virtualMachine.os != QemuConstants.OS_LINUX {
            // A macOS drive cannot be imported: it needs the files created by the macOS installation
            (false, "importDriveMacOSTooltip")
        } else if hasAppleMainDrive {
            (false, "drivesOneDriveTooltip")
        } else {
            (true, "importDriveTooltip")
        }

        for (button, state) in [(openImageButton!, openImage), (createNewDiskButton!, createNewDisk), (importDriveButton!, importDrive)] {
            button.isEnabled = state.enabled
            button.toolTip = NSLocalizedString("EditVMViewControllerHardware." + state.tooltip, comment: "")
        }
    }

    private func showImportNotSupported(_ fileName: String, _ details: DiskImageDetails, _ virtualMachine: VirtualMachine) {
        let message = if details.format == QemuConstants.FORMAT_ASIF {
            String(format: NSLocalizedString("EditVMViewControllerHardware.importDriveAsifNotSupported", comment: ""), fileName)
        } else if details.hasBackingFile {
            String(format: NSLocalizedString("EditVMViewControllerHardware.importDriveBackingRequiresQemuImg", comment: ""), fileName)
        } else {
            String(format: NSLocalizedString("EditVMViewControllerHardware.importDriveRequiresQemuImg", comment: ""), fileName, details.format.uppercased(),
                   Utils.getDirectlyImportableDiskFormats(virtualMachine).map { $0.uppercased() }.joined(separator: ", "))
        }
        Utils.showAlert(window: view.window!, style: .warning, message: message, virtualMachine: virtualMachine)
    }

    private func askToConvert(message: String, detail: String, convertTitle: String, keepTitle: String, completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        if let virtualMachine {
            alert.icon = NSImage(named: NSImage.Name(Utils.getIconForSubType(virtualMachine.os, virtualMachine.subtype) + ".small"))
        }
        alert.alertStyle = .informational
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: convertTitle)
        alert.addButton(withTitle: keepTitle)
        alert.beginSheetModal(for: view.window!, completionHandler: { response in
            completion(response == .alertFirstButtonReturn)
        })
    }

    private func startDriveImport(_ path: String, _ details: DiskImageDetails, targetFormat: String) {
        guard let virtualMachine,
              let importController = storyboard?.instantiateController(withIdentifier: MacMulatorConstants.IMPORT_DRIVE_CONTROLLER) as? ImportDriveViewController
        else { return }

        let mediaType = Utils.getMediaTypeForSubType(virtualMachine.os, virtualMachine.subtype)
        let name = mediaType + "-" + String(Utils.computeNextDriveIndex(virtualMachine, mediaType))
        let gigabyte = 1024.0 * 1024.0 * 1024.0
        let virtualDrive = VirtualDrive(path: virtualMachine.path + "/" + name + "." + MacMulatorConstants.DISK_EXTENSION, name: name, format: targetFormat, mediaType: mediaType, size: Int32((Double(details.virtualSize) / gigabyte).rounded(.up)))
        virtualDrive.setBlank(blank: false)
        // A VM without a boot drive (e.g. one made to run a cloud image) boots from the imported one
        if !virtualMachine.drives.contains(where: \.isBootDrive) {
            virtualDrive.isBootDrive = true
        }

        importController.setImport(from: path, details: details, into: virtualDrive, of: virtualMachine)
        importController.setParentController(self)
        presentAsSheet(importController)
    }
}
