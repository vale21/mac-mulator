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
        print(filename);
        return true;
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
}

