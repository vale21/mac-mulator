//
//  AboutBoxViewController.swift
//  MacMulator
//
//  Created by Vale on 30/08/21.
//

import Cocoa

class AboutBoxViewController: NSViewController {
    
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet weak var licenseButton: NSButton!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var descriptionText: NSTextField!
    @IBOutlet weak var creditsLabel: NSTextField!
    
    @IBAction func openLicense(_ sender: Any) {
        if let url = URL(string: "https://www.apache.org/licenses/LICENSE-2.0.txt") {
            NSWorkspace.shared.open(url)
        }
    }
    
    override func viewWillAppear() {
        var version: String = NSLocalizedString("AboutBoxViewController.version", comment: "");
        if let text = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            version += " " + text;
        }
        if let text = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            version += " (" + text + ")";
        }
        versionLabel.stringValue = version;
        licenseButton.title = NSLocalizedString("AboutBoxViewController.licenseButton", comment: "")
        descriptionLabel.stringValue = NSLocalizedString("AboutBoxViewController.descriptionLabel", comment: "")
        descriptionText.stringValue = NSLocalizedString("AboutBoxViewController.descriptionText", comment: "")
        creditsLabel.stringValue = NSLocalizedString("AboutBoxViewController.creditsLabel", comment: "")
    }
}
