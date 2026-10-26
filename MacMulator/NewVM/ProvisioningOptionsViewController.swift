import Cocoa

class ProvisioningOptionsViewController: NSViewController, NSTextFieldDelegate {
    @IBOutlet var userConfigurationBox: NSBox!
    @IBOutlet var descriptionTextView: NSTextField!
    @IBOutlet var fullNameLabel: NSTextField!
    @IBOutlet var fullNameField: NSTextField!
    @IBOutlet var userNameLabel: NSTextField!
    @IBOutlet var userNameField: NSTextField!
    @IBOutlet var passwordLabel: NSTextField!
    @IBOutlet var passwordField: NSSecureTextField!
    @IBOutlet var retypePasswordLabel: NSTextField!
    @IBOutlet var retypePasswordField: NSSecureTextField!

    @IBOutlet var settingsBox: NSBox!
    @IBOutlet var loginAutomaticallyLabel: NSTextField!
    @IBOutlet var loginAutomaticallySwitch: NSSwitch!
    @IBOutlet var enableSshLabel: NSTextField!
    @IBOutlet var enableSshSwitch: NSSwitch!

    @IBOutlet var skipButton: NSButton!
    @IBOutlet var okButton: NSButton!

    var virtualMachine: VirtualMachine?
    var parentController: NewVMViewController?
    private var userNameEditedManually = false

    func setVirtualMachine(_ virtualMachine: VirtualMachine) {
        self.virtualMachine = virtualMachine
    }

    func setParentController(_ parentController: NewVMViewController) {
        self.parentController = parentController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionTextView.stringValue = NSLocalizedString("ProvisioningOptionsViewController.description", comment: "")
        userConfigurationBox.title = NSLocalizedString("ProvisioningOptionsViewController.userConfigurationBox", comment: "")
        fullNameLabel.stringValue = NSLocalizedString("ProvisioningOptionsViewController.fullNameLabel", comment: "")
        userNameLabel.stringValue = NSLocalizedString("ProvisioningOptionsViewController.userNameLabel", comment: "")
        passwordLabel.stringValue = NSLocalizedString("ProvisioningOptionsViewController.passwordLabel", comment: "")
        retypePasswordLabel.stringValue = NSLocalizedString("ProvisioningOptionsViewController.retypePasswordLabel", comment: "")
        settingsBox.title = NSLocalizedString("ProvisioningOptionsViewController.settingsBox", comment: "")
        loginAutomaticallyLabel.stringValue = NSLocalizedString("ProvisioningOptionsViewController.loginAutomaticallyLabel", comment: "")
        enableSshLabel.stringValue = NSLocalizedString("ProvisioningOptionsViewController.enableSshLabel", comment: "")
        okButton.title = NSLocalizedString("ProvisioningOptionsViewController.okButton", comment: "")
        skipButton.title = NSLocalizedString("ProvisioningOptionsViewController.skipButton", comment: "")
        fullNameField.delegate = self
        userNameField.delegate = self
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === fullNameField {
            if !userNameEditedManually {
                userNameField.stringValue = suggestedUserName(from: fullNameField.stringValue)
            }
        } else if field === userNameField {
            userNameEditedManually = !userNameField.stringValue.isEmpty
        }
    }

    @IBAction func skipVMProvisioning(_: Any) {
        dismiss(self)
        parentController?.vmCreated(virtualMachine!, performProvisioning: false)
    }

    @IBAction func performVMProvisioning(_: Any) {
        guard validateProvisioningInformation() else {
            return
        }

        if let virtualMachine {
            virtualMachine.provisioningInformation = ProvisioningInformation(userFullName: fullNameField.stringValue.trimmingCharacters(in: .whitespaces), userName: userNameField.stringValue.trimmingCharacters(in: .whitespaces), userPassword: passwordField.stringValue, automaticLogin: loginAutomaticallySwitch.state == .on, enableSSh: enableSshSwitch.state == .on)
            virtualMachine.writeToPlist()
        }

        dismiss(self)
        parentController?.vmCreated(virtualMachine!, performProvisioning: false)
    }

    private func validateProvisioningInformation() -> Bool {
        let errorKey: String? = if fullNameField.stringValue.trimmingCharacters(in: .whitespaces).isEmpty {
            "ProvisioningOptionsViewController.fullNameMissing"
        } else if userNameField.stringValue.trimmingCharacters(in: .whitespaces).isEmpty {
            "ProvisioningOptionsViewController.userNameMissing"
        } else if passwordField.stringValue.isEmpty || retypePasswordField.stringValue.isEmpty {
            "ProvisioningOptionsViewController.passwordMissing"
        } else if passwordField.stringValue != retypePasswordField.stringValue {
            "ProvisioningOptionsViewController.passwordMismatch"
        } else {
            nil
        }

        if let errorKey {
            Utils.showAlert(window: view.window!, style: .warning, message: NSLocalizedString(errorKey, comment: ""), virtualMachine: virtualMachine)
            return false
        }
        return true
    }

    private func suggestedUserName(from fullName: String) -> String {
        fullName.lowercased().components(separatedBy: .whitespacesAndNewlines).joined()
    }
}
