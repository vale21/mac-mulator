//
//  EditVMViewControllerCloudInit.swift
//  MacMulator
//
//  Created by Vale on 14/11/2026.
//

import Cocoa

class EditVMViewControllerCloudInit: NSViewController, NSTextFieldDelegate, NSTextViewDelegate, NSPopoverDelegate, VMSettingsLockable {
    @IBOutlet var cloudInitLabel: NSTextField!
    @IBOutlet var cloudInitSwitch: NSSwitch!
    @IBOutlet var descriptionText: NSTextField!
    @IBOutlet var cloudInitBox: NSBox!

    @IBOutlet var fullNameLabel: NSTextField!
    @IBOutlet var fullNameField: NSTextField!
    @IBOutlet var userNameLabel: NSTextField!
    @IBOutlet var userNameField: NSTextField!
    @IBOutlet var passwordLabel: NSTextField!
    @IBOutlet var passwordField: NSSecureTextField!
    @IBOutlet var retypePasswordLabel: NSTextField!
    @IBOutlet var retypePasswordField: NSSecureTextField!
    @IBOutlet var dnsDomainsLabel: NSTextField!
    @IBOutlet var dnsDomainsField: NSTextField!
    @IBOutlet var dnsServersLabel: NSTextField!
    @IBOutlet var dnsServersField: NSTextField!
    @IBOutlet var sshKeysLabel: NSTextField!
    @IBOutlet var sshKeysTextView: NSTextView!
    @IBOutlet var upgradePackagesLabel: NSTextField!
    @IBOutlet var upgradePackagesSwitch: NSSwitch!
    @IBOutlet var ipConfigLabel: NSTextField!
    @IBOutlet var ipConfigButton: NSButton!
    @IBOutlet var ipConfigSummaryText: NSTextField!
    @IBOutlet var validationText: NSTextField!

    // Shown in a popover by ipConfigButton
    @IBOutlet var ipConfigView: NSView!
    @IBOutlet var networkDeviceLabel: NSTextField!
    @IBOutlet var ipv4StaticRadio: NSButton!
    @IBOutlet var ipv4DhcpRadio: NSButton!
    @IBOutlet var ipv4CidrField: NSTextField!
    @IBOutlet var ipv4GatewayLabel: NSTextField!
    @IBOutlet var ipv4GatewayField: NSTextField!
    @IBOutlet var ipv6NoneRadio: NSButton!
    @IBOutlet var ipv6StaticRadio: NSButton!
    @IBOutlet var ipv6DhcpRadio: NSButton!
    @IBOutlet var ipv6SlaacRadio: NSButton!
    @IBOutlet var ipv6CidrField: NSTextField!
    @IBOutlet var ipv6GatewayLabel: NSTextField!
    @IBOutlet var ipv6GatewayField: NSTextField!

    var virtualMachine: VirtualMachine?
    var vmLocked = false
    private var userNameEditedManually = false
    private lazy var ipConfigPopover: NSPopover = {
        let controller = NSViewController()
        controller.view = ipConfigView
        controller.preferredContentSize = ipConfigView.fittingSize
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.delegate = self
        return popover
    }()

    func setVirtualMachine(_ vm: VirtualMachine) {
        virtualMachine = vm
        if isViewLoaded {
            populateView()
        }
    }

    func setVMLocked(_ locked: Bool) {
        vmLocked = locked
        if isViewLoaded {
            updateView()
        }
    }

    @IBAction func cloudInitToggleChanged(_: Any) {
        if cloudInitSwitch.state == .on {
            // Nothing is validated until the user edits a field: an empty form is not an error yet
            saveProvisioningInformation()
        } else if let virtualMachine, let provisioningInformation = virtualMachine.provisioningInformation {
            provisioningInformation.cleanup()
            virtualMachine.provisioningInformation = nil
        }
        updateView()
    }

    @IBAction func showIPConfiguration(_ sender: NSButton) {
        ipConfigPopover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    // Radio buttons sharing the same action and superview are mutually exclusive
    @IBAction func ipv4ModeChanged(_: Any) {
        updateIPFields()
        saveProvisioningInformation()
    }

    @IBAction func ipv6ModeChanged(_: Any) {
        updateIPFields()
        saveProvisioningInformation()
    }

    @IBAction func upgradePackagesToggleChanged(_: Any) {
        saveProvisioningInformation()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        localizeUI()
        let fields: [NSTextField] = [fullNameField, userNameField, passwordField, retypePasswordField, dnsDomainsField,
                                     dnsServersField, ipv4CidrField, ipv4GatewayField, ipv6CidrField, ipv6GatewayField]
        for field in fields {
            field.delegate = self
        }
        sshKeysTextView.delegate = self
        sshKeysTextView.isAutomaticQuoteSubstitutionEnabled = false
        sshKeysTextView.isAutomaticDashSubstitutionEnabled = false
        sshKeysTextView.isAutomaticTextReplacementEnabled = false
        sshKeysTextView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        populateView()
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
        saveProvisioningInformation()
    }

    func textDidEndEditing(_: Notification) {
        saveProvisioningInformation()
    }

    func popoverDidClose(_: Notification) {
        saveProvisioningInformation()
    }

    private func localizeUI() {
        func localized(_ key: String) -> String {
            NSLocalizedString("EditVMViewControllerCloudInit." + key, comment: "")
        }
        cloudInitLabel.stringValue = localized("cloudInitLabel")
        descriptionText.stringValue = localized("description")
        fullNameLabel.stringValue = localized("fullNameLabel")
        userNameLabel.stringValue = localized("userNameLabel")
        passwordLabel.stringValue = localized("passwordLabel")
        retypePasswordLabel.stringValue = localized("retypePasswordLabel")
        dnsDomainsLabel.stringValue = localized("dnsDomainsLabel")
        dnsServersLabel.stringValue = localized("dnsServersLabel")
        sshKeysLabel.stringValue = localized("sshKeysLabel")
        upgradePackagesLabel.stringValue = localized("upgradePackagesLabel")
        ipConfigLabel.stringValue = localized("ipConfigLabel")
        ipConfigButton.title = localized("ipConfigButton")
        networkDeviceLabel.stringValue = localized("networkDeviceLabel")
        ipv4StaticRadio.title = localized("staticRadio")
        ipv6StaticRadio.title = localized("staticRadio")
        ipv6NoneRadio.title = localized("noneRadio")
        ipv4GatewayLabel.stringValue = localized("gatewayIPv4Label")
        ipv6GatewayLabel.stringValue = localized("gatewayIPv6Label")
    }

    private func populateView() {
        guard let virtualMachine else { return }
        let info = virtualMachine.provisioningInformation
        cloudInitSwitch.state = info != nil ? .on : .off
        fullNameField.stringValue = info?.userFullName ?? ""
        userNameField.stringValue = info?.userName ?? ""
        userNameEditedManually = !userNameField.stringValue.isEmpty
        let password = info?.userPassword ?? ""
        passwordField.stringValue = password
        retypePasswordField.stringValue = password
        dnsDomainsField.stringValue = info?.dnsDomains.joined(separator: " ") ?? ""
        dnsServersField.stringValue = info?.dnsServers.joined(separator: " ") ?? ""
        sshKeysTextView.string = info?.sshKeys.joined(separator: "\n") ?? ""
        upgradePackagesSwitch.state = info?.upgradePackages == true ? .on : .off

        let ipConfiguration = info?.ipConfiguration ?? CloudInitIPConfiguration()
        ipv4StaticRadio.state = ipConfiguration.ipv4Mode == .staticAddress ? .on : .off
        ipv4DhcpRadio.state = ipConfiguration.ipv4Mode == .dhcp ? .on : .off
        ipv4CidrField.stringValue = ipConfiguration.ipv4Cidr
        ipv4GatewayField.stringValue = ipConfiguration.ipv4Gateway
        ipv6NoneRadio.state = ipConfiguration.ipv6Mode == .disabled ? .on : .off
        ipv6StaticRadio.state = ipConfiguration.ipv6Mode == .staticAddress ? .on : .off
        ipv6DhcpRadio.state = ipConfiguration.ipv6Mode == .dhcp ? .on : .off
        ipv6SlaacRadio.state = ipConfiguration.ipv6Mode == .slaac ? .on : .off
        ipv6CidrField.stringValue = ipConfiguration.ipv6Cidr
        ipv6GatewayField.stringValue = ipConfiguration.ipv6Gateway

        validationText.isHidden = true
        updateIPFields()
        updateView()
    }

    private func updateView() {
        let enabled = cloudInitSwitch.state == .on && !vmLocked
        cloudInitSwitch.isEnabled = !vmLocked
        let controls: [NSControl] = [fullNameLabel, fullNameField, userNameLabel, userNameField, passwordLabel, passwordField,
                                     retypePasswordLabel, retypePasswordField, dnsDomainsLabel, dnsDomainsField, dnsServersLabel,
                                     dnsServersField, sshKeysLabel, upgradePackagesLabel, upgradePackagesSwitch, ipConfigLabel,
                                     ipConfigButton, ipConfigSummaryText, validationText]
        for control in controls {
            control.isEnabled = enabled
        }
        sshKeysTextView.isEditable = enabled
        sshKeysTextView.isSelectable = enabled
        sshKeysTextView.textColor = enabled ? .textColor : .disabledControlTextColor
        if !enabled {
            validationText.isHidden = true
        }
        updateIPConfigSummary()
    }

    private func updateIPFields() {
        let ipv4Static = ipv4StaticRadio.state == .on
        ipv4CidrField.isEnabled = ipv4Static
        ipv4GatewayField.isEnabled = ipv4Static
        let ipv6Static = ipv6StaticRadio.state == .on
        ipv6CidrField.isEnabled = ipv6Static
        ipv6GatewayField.isEnabled = ipv6Static
        updateIPConfigSummary()
    }

    private func updateIPConfigSummary() {
        let ipv4 = ipv4DhcpRadio.state == .on ? "DHCP" : ipv4CidrField.stringValue
        let ipv6 = if ipv6DhcpRadio.state == .on {
            "DHCP"
        } else if ipv6SlaacRadio.state == .on {
            "SLAAC"
        } else {
            ipv6CidrField.stringValue
        }
        let notSet = NSLocalizedString("EditVMViewControllerCloudInit.notSet", comment: "")
        let ipv6Summary = ipv6NoneRadio.state == .on ? NSLocalizedString("EditVMViewControllerCloudInit.ipv6Disabled", comment: "") : "IPv6: \(ipv6.isEmpty ? notSet : ipv6)"
        ipConfigSummaryText.stringValue = "IPv4: \(ipv4.isEmpty ? notSet : ipv4) – \(ipv6Summary)"
    }

    private func saveProvisioningInformation() {
        updateIPConfigSummary()
        guard let virtualMachine, cloudInitSwitch.state == .on else { return }
        do {
            try populateProvisioningInformation(of: virtualMachine)
            validationText.isHidden = true
        } catch let error as CloudInitValidationError {
            showValidationError(error.localizedMessage)
        } catch {
            showValidationError(error.localizedDescription)
        }
    }

    private func showValidationError(_ message: String) {
        validationText.stringValue = String(format: NSLocalizedString("EditVMViewControllerCloudInit.notSaved", comment: ""), message)
        validationText.isHidden = false
    }

    private func populateProvisioningInformation(of virtualMachine: VirtualMachine) throws {
        let prefix = "EditVMViewControllerCloudInit."
        let fullName = fullNameField.stringValue.trimmingCharacters(in: .whitespaces)
        let userName = userNameField.stringValue.trimmingCharacters(in: .whitespaces)
        let password = passwordField.stringValue

        if fullName.isEmpty {
            throw CloudInitValidationError(prefix + "fullNameMissing")
        }
        if userName.isEmpty {
            throw CloudInitValidationError(prefix + "userNameMissing")
        }
        if !CloudInitValidator.isValidUserName(userName) {
            throw CloudInitValidationError(prefix + "userNameInvalid")
        }
        if password.isEmpty || retypePasswordField.stringValue.isEmpty {
            throw CloudInitValidationError(prefix + "passwordMissing")
        }
        if password != retypePasswordField.stringValue {
            throw CloudInitValidationError(prefix + "passwordMismatch")
        }

        let dnsDomains = try CloudInitValidator.parseDnsDomains(dnsDomainsField.stringValue)
        let dnsServers = try CloudInitValidator.parseDnsServers(dnsServersField.stringValue)
        let sshKeys = try CloudInitValidator.parseSshKeys(sshKeysTextView.string)

        let ipv4Mode: CloudInitIPv4Mode = ipv4DhcpRadio.state == .on ? .dhcp : .staticAddress
        let ipv6Mode: CloudInitIPv6Mode = if ipv6NoneRadio.state == .on {
            .disabled
        } else if ipv6DhcpRadio.state == .on {
            .dhcp
        } else if ipv6SlaacRadio.state == .on {
            .slaac
        } else {
            .staticAddress
        }
        let ipConfiguration = try CloudInitValidator.buildIPConfiguration(ipv4Mode: ipv4Mode, ipv4Cidr: ipv4CidrField.stringValue, ipv4Gateway: ipv4GatewayField.stringValue, ipv6Mode: ipv6Mode, ipv6Cidr: ipv6CidrField.stringValue, ipv6Gateway: ipv6GatewayField.stringValue)
        let upgradePackages = upgradePackagesSwitch.state == .on

        if let info = virtualMachine.provisioningInformation {
            // Update in place, so that the password keeps its keychain item
            info.userFullName = fullName
            info.userName = userName
            if info.userPassword != password {
                info.userPassword = password
            }
            info.enableSSh = !sshKeys.isEmpty
            info.dnsDomains = dnsDomains
            info.dnsServers = dnsServers
            info.sshKeys = sshKeys
            info.upgradePackages = upgradePackages
            info.ipConfiguration = ipConfiguration
        } else {
            virtualMachine.provisioningInformation = ProvisioningInformation(userFullName: fullName, userName: userName, userPassword: password, dnsDomains: dnsDomains, dnsServers: dnsServers, sshKeys: sshKeys, upgradePackages: upgradePackages, ipConfiguration: ipConfiguration)
        }
    }

    private func suggestedUserName(from fullName: String) -> String {
        fullName.lowercased().components(separatedBy: .whitespacesAndNewlines).joined()
    }
}
