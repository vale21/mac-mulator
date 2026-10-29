//
//  CloneVMViewController.swift
//  MacMulator
//
//  Created by Vale on 28/10/2026.
//

import Cocoa

enum CloneType: Int, CaseIterable {
    case full
    case linked

    var title: String {
        switch self {
        case .full:
            NSLocalizedString("CloneVMViewController.fullClone", comment: "")
        case .linked:
            NSLocalizedString("CloneVMViewController.linkedClone", comment: "")
        }
    }

    var explanation: String {
        switch self {
        case .full:
            NSLocalizedString("CloneVMViewController.fullCloneDescription", comment: "")
        case .linked:
            NSLocalizedString("CloneVMViewController.linkedCloneDescription", comment: "")
        }
    }
}

class CloneVMViewController: NSViewController, NSComboBoxDelegate, NSComboBoxDataSource {
    @IBOutlet var cloneTypeLabel: NSTextField!
    @IBOutlet var cloneTypeComboBox: NSComboBox!
    @IBOutlet var cloneDescriptionLabel: NSTextField!

    @IBOutlet var cancelButton: NSButton!
    @IBOutlet var okButton: NSButton!

    var parentController: VirtualMachineViewController?
    var virtualMachine: VirtualMachine?

    func setParentController(_ parentController: VirtualMachineViewController) {
        self.parentController = parentController
    }

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        cloneTypeLabel.stringValue = NSLocalizedString("CloneVMViewController.cloneType", comment: "")
        cancelButton.title = NSLocalizedString("CloneVMViewController.cancel", comment: "")
        okButton.title = NSLocalizedString("CloneVMViewController.clone", comment: "")

        cloneTypeComboBox.isEditable = false
        // The combo box is configured to use a data source in the storyboard
        cloneTypeComboBox.usesDataSource = true
        cloneTypeComboBox.dataSource = self
        cloneTypeComboBox.delegate = self
        cloneTypeComboBox.reloadData()
        cloneTypeComboBox.selectItem(at: CloneType.linked.rawValue)
        updateDescription()
    }

    private var selectedCloneType: CloneType {
        CloneType(rawValue: cloneTypeComboBox.indexOfSelectedItem) ?? .linked
    }

    private func updateDescription() {
        cloneDescriptionLabel.stringValue = selectedCloneType.explanation
    }

    func numberOfItems(in _: NSComboBox) -> Int {
        CloneType.allCases.count
    }

    func comboBox(_: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        CloneType(rawValue: index)?.title
    }

    func comboBoxSelectionDidChange(_: Notification) {
        updateDescription()
    }

    @IBAction func cancelButtonPressed(_: Any) {
        dismiss(self)
    }

    @IBAction func okButtonPressed(_: Any) {
        let cloneType = selectedCloneType
        dismiss(self)

        guard let virtualMachine, let rootController = parentController?.rootController else {
            return
        }
        switch cloneType {
        case .full:
            rootController.performFullClone(virtualMachine)
        case .linked:
            rootController.performLinkedClone(virtualMachine)
        }
    }
}
