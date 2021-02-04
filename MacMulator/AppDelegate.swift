//
//  AppDelegate.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var app: NSApplication?;
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if (performSanityCheck(filename)) {
            let rootViewController = app?.mainWindow?.contentViewController as? RootViewController;
            rootViewController?.addVirtualMachineFromFile(filename);
            return true;
        } else {
            Utils.showAlert(window: sender.mainWindow!, style: NSAlert.Style.warning,
                            message: "Could not open file " + filename + ". It migh be corrupted.");
            return false;
        }
    }
        
    @IBAction func newVMMenuBarClicked(_ sender: Any) {
        app?.mainWindow?.windowController?.performSegue(withIdentifier: "newVMSegue", sender: self);
    }
    
    @IBAction func openVMMenuBarClicked(_ sender: Any) {
        Utils.showFileSelector(fileTypes: ["qvm"], uponSelection: { panel in self.application(app!, openFile: String(panel.url!.path)) });
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.app = aNotification.object as? NSApplication;
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    fileprivate func performSanityCheck(_ filename: String) -> Bool{
        if (filename.hasSuffix(".qvm")) {
            
            let fileManager = FileManager.default;
            do {
                let fileNames: [String] = try fileManager.contentsOfDirectory(atPath: filename);
                for file in fileNames {
                    if (file == "Info.plist") {
                        return true;
                    }
                }
            } catch {
                print("ERROR while reading" + filename);
            }
        }
        
        return false;
    }
}

