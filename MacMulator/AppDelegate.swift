//
//  AppDelegate.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if (performSanityCheck(filename)) {
            let rootViewController = sender.mainWindow?.contentViewController as! RootViewController;
            rootViewController.addVirtualMachineFromFile(filename);
            return true;
        } else {
            let alert: NSAlert = NSAlert();
            alert.alertStyle = NSAlert.Style.warning;
            alert.messageText = "Coul not open file " + filename + ". It migh be corrupted.";
            alert.addButton(withTitle: "OK");
            alert.beginSheetModal(for: sender.mainWindow!, completionHandler: nil);
            return false;
        }
    }
    
    private func performSanityCheck(_ filename: String) -> Bool{
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
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
}

