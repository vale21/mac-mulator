//
//  AboutBoxViewController.swift
//  MacMulator
//
//  Created by Vale on 30/08/21.
//

import Cocoa

class AboutBoxViewController: NSViewController {
    @IBOutlet var versionLabel: NSTextField!

    @IBAction func openLicense(_: Any) {
        if let url = URL(string: "https://www.apache.org/licenses/LICENSE-2.0.txt") {
            NSWorkspace.shared.open(url)
        }
    }

    override func viewWillAppear() {
        var version = "Version"
        if let text = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            version += " " + text
        }
        if let text = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            version += " (" + text + ")"
        }
        versionLabel.stringValue = version
    }
}
