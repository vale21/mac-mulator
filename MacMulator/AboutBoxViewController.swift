//
//  AboutBoxViewController.swift
//  MacMulator
//
//  Created by Vale on 30/08/21.
//

import Cocoa

class AboutBoxViewController: NSViewController {
    
    @IBOutlet weak var versionLabel: NSTextField!
    
    override func viewWillAppear() {
        var version: String = "Version";
        if let text = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            version += " " + text;
        }
        if let text = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            version += " (" + text + ")";
        }
        versionLabel.stringValue = version;
    }
}
