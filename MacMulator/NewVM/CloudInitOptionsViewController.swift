import Cocoa

class CloudInitOptionsViewController: NSViewController, NSTextFieldDelegate {
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

    @IBOutlet var dnsDomainsLabel: NSTextField!
    @IBOutlet var dnsDomainsField: NSTextField!
    @IBOutlet var dnsServersLabel: NSTextField!
    @IBOutlet var dnsServersField: NSTextField!
    @IBOutlet var sshKeysLabel: NSTextField!
    @IBOutlet var sshKeysTextView: NSTextView!
    @IBOutlet var upgradePackagesLabel: NSTextField!
    @IBOutlet var upgradePackagesSwitch: NSSwitch!

    @IBOutlet var ipConfigBox: NSBox!
    @IBOutlet var networkDeviceLabel: NSTextField!
    @IBOutlet var ipv4StaticRadio: NSButton!
    @IBOutlet var ipv4DhcpRadio: NSButton!
    @IBOutlet var ipv4CidrField: NSTextField!
    @IBOutlet var ipv4GatewayLabel: NSTextField!
    @IBOutlet var ipv4GatewayField: NSTextField!
    @IBOutlet var ipv6StaticRadio: NSButton!
    @IBOutlet var ipv6DhcpRadio: NSButton!
    @IBOutlet var ipv6SlaacRadio: NSButton!
    @IBOutlet var ipv6CidrField: NSTextField!
    @IBOutlet var ipv6GatewayLabel: NSTextField!
    @IBOutlet var ipv6GatewayField: NSTextField!

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
        localizeUI()
        fullNameField.delegate = self
        userNameField.delegate = self
        sshKeysTextView.isAutomaticQuoteSubstitutionEnabled = false
        sshKeysTextView.isAutomaticDashSubstitutionEnabled = false
        sshKeysTextView.isAutomaticTextReplacementEnabled = false
        sshKeysTextView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        ipv4StaticRadio.state = .on
        ipv6StaticRadio.state = .on
        updateIPv4Fields()
        updateIPv6Fields()
    }

    private func localizeUI() {
        func localized(_ key: String) -> String {
            NSLocalizedString("CloudInitOptionsViewController." + key, comment: "")
        }
        descriptionTextView.stringValue = localized("description")
        userConfigurationBox.title = localized("userConfigurationBox")
        fullNameLabel.stringValue = localized("fullNameLabel")
        userNameLabel.stringValue = localized("userNameLabel")
        passwordLabel.stringValue = localized("passwordLabel")
        retypePasswordLabel.stringValue = localized("retypePasswordLabel")
        settingsBox.title = localized("settingsBox")
        dnsDomainsLabel.stringValue = localized("dnsDomainsLabel")
        dnsServersLabel.stringValue = localized("dnsServersLabel")
        sshKeysLabel.stringValue = localized("sshKeysLabel")
        upgradePackagesLabel.stringValue = localized("upgradePackagesLabel")
        ipConfigBox.title = localized("ipConfigBox")
        networkDeviceLabel.stringValue = localized("networkDeviceLabel")
        ipv4StaticRadio.title = localized("staticRadio")
        ipv6StaticRadio.title = localized("staticRadio")
        ipv4GatewayLabel.stringValue = localized("gatewayIPv4Label")
        ipv6GatewayLabel.stringValue = localized("gatewayIPv6Label")
        okButton.title = localized("okButton")
        skipButton.title = localized("skipButton")
    }

    // Radio buttons sharing the same action and superview are mutually exclusive
    @IBAction func ipv4ModeChanged(_: Any) {
        updateIPv4Fields()
    }

    @IBAction func ipv6ModeChanged(_: Any) {
        updateIPv6Fields()
    }

    private func updateIPv4Fields() {
        let isStatic = ipv4StaticRadio.state == .on
        ipv4CidrField.isEnabled = isStatic
        ipv4GatewayField.isEnabled = isStatic
    }

    private func updateIPv6Fields() {
        let isStatic = ipv6StaticRadio.state == .on
        ipv6CidrField.isEnabled = isStatic
        ipv6GatewayField.isEnabled = isStatic
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
        let provisioningInformation: ProvisioningInformation
        do {
            provisioningInformation = try validatedProvisioningInformation()
        } catch let error as CloudInitValidationError {
            showValidationError(error.localizedMessage)
            return
        } catch {
            showValidationError(error.localizedDescription)
            return
        }

        if let virtualMachine {
            virtualMachine.provisioningInformation = provisioningInformation
            virtualMachine.writeToPlist()
        }

        dismiss(self)
        parentController?.vmCreated(virtualMachine!, performProvisioning: false)
    }

    private func showValidationError(_ message: String) {
        Utils.showAlert(window: view.window!, style: .warning, message: message, virtualMachine: virtualMachine)
    }

    /// Validates every field and builds the provisioning information from them. Throws on the first invalid field.
    private func validatedProvisioningInformation() throws -> ProvisioningInformation {
        let prefix = "CloudInitOptionsViewController."
        let fullName = fullNameField.stringValue.trimmingCharacters(in: .whitespaces)
        let userName = userNameField.stringValue.trimmingCharacters(in: .whitespaces)

        if fullName.isEmpty {
            throw CloudInitValidationError(prefix + "fullNameMissing")
        }
        if userName.isEmpty {
            throw CloudInitValidationError(prefix + "userNameMissing")
        }
        if !CloudInitValidator.isValidUserName(userName) {
            throw CloudInitValidationError(prefix + "userNameInvalid")
        }
        if passwordField.stringValue.isEmpty || retypePasswordField.stringValue.isEmpty {
            throw CloudInitValidationError(prefix + "passwordMissing")
        }
        if passwordField.stringValue != retypePasswordField.stringValue {
            throw CloudInitValidationError(prefix + "passwordMismatch")
        }

        let dnsDomains = try CloudInitValidator.parseDnsDomains(dnsDomainsField.stringValue)
        let dnsServers = try CloudInitValidator.parseDnsServers(dnsServersField.stringValue)
        let sshKeys = try CloudInitValidator.parseSshKeys(sshKeysTextView.string)

        let ipv4Mode: CloudInitIPv4Mode = ipv4DhcpRadio.state == .on ? .dhcp : .staticAddress
        let ipv6Mode: CloudInitIPv6Mode = if ipv6DhcpRadio.state == .on {
            .dhcp
        } else if ipv6SlaacRadio.state == .on {
            .slaac
        } else {
            .staticAddress
        }
        let ipConfiguration = try CloudInitValidator.buildIPConfiguration(ipv4Mode: ipv4Mode, ipv4Cidr: ipv4CidrField.stringValue, ipv4Gateway: ipv4GatewayField.stringValue, ipv6Mode: ipv6Mode, ipv6Cidr: ipv6CidrField.stringValue, ipv6Gateway: ipv6GatewayField.stringValue)

        return ProvisioningInformation(userFullName: fullName, userName: userName, userPassword: passwordField.stringValue, dnsDomains: dnsDomains, dnsServers: dnsServers, sshKeys: sshKeys, upgradePackages: upgradePackagesSwitch.state == .on, ipConfiguration: ipConfiguration)
    }

    private func suggestedUserName(from fullName: String) -> String {
        fullName.lowercased().components(separatedBy: .whitespacesAndNewlines).joined()
    }
}
