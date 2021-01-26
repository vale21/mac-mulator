//
//  ViewController.swift
//  QManage
//
//  Created by Vale on 26/01/21.
//

import Cocoa

class ViewController: NSViewController {

    var isRunning = false;
    
    @IBAction
    func buttonClicked(sender: NSButton) {
        if (isRunning) {
            let alert: NSAlert = NSAlert();
            alert.alertStyle = NSAlert.Style.critical;
            alert.messageText = "Cannor run multiple times";
            alert.addButton(withTitle: "OK");
            alert.beginSheetModal(for: self.view.window!, completionHandler: nil);
            
        } else {
            let dispatchQueue = DispatchQueue(label: "Qemu Thread");
            dispatchQueue.async {
                self.isRunning = true;
                
                print(self.shell("/opt/local/qemu/qemu-system-ppc -L pc-bios -boot c -M mac99,via=pmu -m 2048 -g 1440x900x32 -prom-env 'auto-boot?=true' -prom-env 'vga-ndrv?=true' -drive file=/Volumes/valeMac\\ SSD/Parallels/Tiger.qvm/Tiger_hdd.qcow2,format=qcow2,media=disk -netdev user,id=mynet0 -device sungem,netdev=mynet0"));
                
                self.isRunning = false;
            }
        }
    }

    func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        return output
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

