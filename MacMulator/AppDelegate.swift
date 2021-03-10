//
//  AppDelegate.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var savedVMs: [String]? = [];
    private var rootController: RootViewController?;

    @IBAction func newVMMenuBarClicked(_ sender: Any) {
        NSApp.mainWindow?.windowController?.performSegue(withIdentifier: MacMulatorConstants.NEW_VM_SEGUE, sender: self);
    }
    
    @IBAction func openVMMenuBarClicked(_ sender: Any) {
        Utils.showFileSelector(fileTypes: [MacMulatorConstants.VM_EXTENSION], uponSelection: { panel in self.application(NSApp, openFile: String(panel.url!.path)) });
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if (performSanityCheck(filename)) {
            rootController?.addVirtualMachineFromFile(filename);
            return true;
        } else {
            Utils.showAlert(window: sender.mainWindow!, style: NSAlert.Style.warning,
                            message: "Could not open file " + filename + ". It migh be corrupted.");
            return false;
        }
    }
                
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let userDefaults = UserDefaults.standard;
        //userDefaults.removeObject(forKey: "savedVMs");
        
        self.savedVMs = userDefaults.object(forKey: "savedVMs") as? [String];
        if self.savedVMs == nil {
            self.savedVMs = [];
        }
        
        setupSavedVMs();
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        let userDefaults = UserDefaults.standard;
        userDefaults.set(savedVMs, forKey: "savedVMs");
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true;
    }
    
    func setupSavedVMs() {
        let filemanager = FileManager.default;
        var toRemove: [Int] = [];
        for savedVM in savedVMs! {
            if filemanager.fileExists(atPath: savedVM) && performSanityCheck(savedVM) {
                rootController?.addVirtualMachineFromFile(savedVM);
            } else {
                toRemove.append((savedVMs?.lastIndex(of: savedVM))!);
            }
        }
        
        if (toRemove.count > 0) {
            var removed:[String] = [];
            toRemove.reverse();
            for index in toRemove {
                removed.append((savedVMs?.remove(at: index))!);
            }
            
            rootController?.showAlert("Could not find some Virtual Machines that were configured in MacMulator: " + removed.joined(separator: ", "));

            let userDefaults = UserDefaults.standard;
            userDefaults.set(savedVMs, forKey: "savedVMs");
        }
    }
    
    func addSavedVM(_ savedVM: String) {
        let vmToSave = Utils.unescape(savedVM);
        if !(savedVMs!.contains(vmToSave)) {
            savedVMs!.append(vmToSave);
        }
        
        let userDefaults = UserDefaults.standard;
        userDefaults.set(savedVMs, forKey: "savedVMs");
    }
    
    func removeSavedVM(_ savedVM: String) {
        let vmToRemove = Utils.unescape(savedVM);
        let index = (savedVMs?.firstIndex(of: vmToRemove))!;
        savedVMs?.remove(at: index);
        
        let fileManager = FileManager.default;
        do {
            try fileManager.removeItem(at: URL(fileURLWithPath: savedVM));
        } catch {
            print("ERROR while deleting" + savedVM + ": " + error.localizedDescription);
        }

        
        let userDefaults = UserDefaults.standard;
        userDefaults.set(savedVMs, forKey: "savedVMs");
    }
    
    func rootControllerDidFinishLoading(_ rootController: RootViewController) {
        self.rootController = rootController;
    }
    
    fileprivate func performSanityCheck(_ filename: String) -> Bool{
        if (filename.hasSuffix("." + MacMulatorConstants.VM_EXTENSION)) {
            
            let fileManager = FileManager.default;
            do {
                let fileNames: [String] = try fileManager.contentsOfDirectory(atPath: filename);
                for file in fileNames {
                    if (file == MacMulatorConstants.INFO_PLIST) {
                        return true;
                    }
                }
            } catch {
                print("ERROR while reading" + filename + ": " + error.localizedDescription);
            }
        }
        
        return false;
    }
}

