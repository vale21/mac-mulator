//
//  VirtualizationFrameworkPauseResumeVMViewController.swift
//  MacMulator
//
//  Created by Vale on 04/11/23.
//

import Cocoa

@available(macOS 12.0, *)
class VirtualizationFrameworkPauseResumeVMViewController: NSViewController {
    @IBOutlet var progressSpinner: NSProgressIndicator!
    @IBOutlet var descriptionLabel: NSTextField!
    @IBOutlet var vmIcon: NSImageView!

    var parentRunner: VirtualizationFrameworkVirtualMachineRunner?
    var operation: String?
    var dismissalCriteria: () -> Bool = { false }
    var dismissInProgress = false
    var alertMessage: String?

    func setParentRunner(_ parentRunner: VirtualizationFrameworkVirtualMachineRunner) {
        self.parentRunner = parentRunner
    }

    func setOperation(_ operation: String) {
        self.operation = operation
    }

    func setDismissalCriteria(_ dismissalCriteria: @escaping () -> Bool = { false }) {
        self.dismissalCriteria = dismissalCriteria
    }

    func setAlertMessage(_ alertMessage: String?) {
        self.alertMessage = alertMessage
    }

    override func viewDidLoad() {
        let vm = parentRunner?.managedVm
        if let vm {
            vmIcon.image = NSImage(named: NSImage.Name(Utils.getIconForSubType(vm.os, vm.subtype) + ".large"))
        }

        progressSpinner.startAnimation(self)

        if operation == "Pausing" {
            descriptionLabel.stringValue = NSLocalizedString("VirtualizationFrameworkPauseResumeVMViewController.pausing", comment: "")
        } else if operation == "Resuming" {
            descriptionLabel.stringValue = NSLocalizedString("VirtualizationFrameworkPauseResumeVMViewController.resuming", comment: "")
        } else {
            descriptionLabel.stringValue = "Creating VM snapshot..."
        }

        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
                if self.dismissalCriteria(), !self.dismissInProgress {
                    self.dismissInProgress = true
                    if self.alertMessage != nil {
                        Utils.showAlert(window: self.view.window!, style: NSAlert.Style.informational, message: self.alertMessage!, completionHandler: { _ in self.dismiss(self) }, virtualMachine: nil)
                    } else {
                        self.dismiss(self)
                    }
                }
            })
        }
    }
}
