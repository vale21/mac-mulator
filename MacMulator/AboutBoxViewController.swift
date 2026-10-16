//
//  AboutBoxViewController.swift
//  MacMulator
//
//  Created by Vale on 30/08/21.
//

import Cocoa

class AboutBoxViewController: NSViewController {
    @IBOutlet var versionLabel: NSTextField!
    @IBOutlet var licenseButton: NSButton!
    @IBOutlet var descriptionLabel: NSTextField!
    @IBOutlet var descriptionText: NSTextField!
    @IBOutlet var creditsLabel: NSTextField!
    @IBOutlet var copyrightLabel: NSTextField!

    private var thirdPartyCreditsAppended = false

    @IBAction func openLicense(_: Any) {
        if let url = URL(string: "https://www.apache.org/licenses/LICENSE-2.0.txt") {
            NSWorkspace.shared.open(url)
        }
    }

    override func viewWillAppear() {
        var version: String = NSLocalizedString("AboutBoxViewController.version", comment: "")
        if let text = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            version += " " + text
        }
        if let text = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            version += " (" + text + ")"
        }
        versionLabel.stringValue = version
        licenseButton.title = NSLocalizedString("AboutBoxViewController.licenseButton", comment: "")
        descriptionLabel.stringValue = NSLocalizedString("AboutBoxViewController.descriptionLabel", comment: "")
        descriptionText.stringValue = NSLocalizedString("AboutBoxViewController.descriptionText", comment: "")
        creditsLabel.stringValue = NSLocalizedString("AboutBoxViewController.creditsLabel", comment: "")

        // Keep the copyright year current instead of hardcoding it in the storyboard
        let year = String(Calendar.current.component(.year, from: Date()))
        copyrightLabel.stringValue = String(format: NSLocalizedString("AboutBoxViewController.copyright", comment: ""), year)

        appendThirdPartyCredits()
    }

    private func appendThirdPartyCredits() {
        guard !thirdPartyCreditsAppended,
              let textView = findTextView(in: view),
              let storage = textView.textStorage,
              let licensesURL = Bundle.main.url(forResource: "ThirdPartyLicenses", withExtension: "txt")
        else {
            return
        }
        thirdPartyCreditsAppended = true

        // Same look as the credits already in the storyboard.
        var attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.textColor]
        if storage.length > 0 {
            attributes = storage.attributes(at: storage.length - 1, effectiveRange: nil)
            attributes.removeValue(forKey: .link)
        }
        var linkAttributes = attributes
        linkAttributes[.link] = licensesURL

        let credits = NSMutableAttributedString(string: "\n\n" + NSLocalizedString("AboutBoxViewController.thirdPartyText", comment: ""), attributes: attributes)
        credits.append(NSAttributedString(string: NSLocalizedString("AboutBoxViewController.thirdPartyLink", comment: ""), attributes: linkAttributes))
        storage.append(credits)
    }

    private func findTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView {
            return textView
        }
        for subview in view.subviews {
            if let textView = findTextView(in: subview) {
                return textView
            }
        }
        return nil
    }
}
