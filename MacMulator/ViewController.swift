//
//  ViewController.swift
//  QManage
//
//  Created by Vale on 26/01/21.
//

import Cocoa

class ViewController: NSViewController {

    let libraryPath = "/Volumes/valeMac\\ SSD/Parallels";
    let qemuPath = "/opt/local/qemu/qemu-system-ppc";
    
    var isRunning = false;
    var vm : VirtualMachine?
    
    @IBOutlet weak var vmName: NSTextField!
    @IBOutlet weak var vmFilePath: NSTextField!
    @IBOutlet weak var vmResolution: NSTextField!
    @IBOutlet weak var vmMemory: NSTextField!
    
    @IBAction
    func buttonClicked(sender: NSButton) {
        
        if let vm = self.vm {
            if (isRunning) {
                let alert: NSAlert = NSAlert();
                alert.alertStyle = NSAlert.Style.critical;
                alert.messageText = "Virtual Machine " + vm.displayName + " is already running!";
                alert.addButton(withTitle: "OK");
                alert.beginSheetModal(for: self.view.window!, completionHandler: nil);
                
            } else {
                let dispatchQueue = DispatchQueue(label: "Qemu Thread");
                dispatchQueue.async {
                    self.isRunning = true;
                    
                    let memory: String = String(vm.memory);
                    let res: String = vm.resolution;
                    
                    let drive: String = self.libraryPath + "/" + self.escape(text: vm.displayName) + ".qvm/" + vm.drives[0].name + "." + vm.drives[0].format + ",format=" + vm.drives[0].format + ",media=" + vm.drives[0].mediaType
                    
                    let command: String = self.qemuPath
                        + " -L pc-bios -boot c -M mac99,via=pmu -m " + memory
                        + " -g " + res + " -prom-env 'auto-boot?=true' -prom-env 'vga-ndrv?=true' -drive file=" + drive
                        + " -netdev user,id=mynet0 -device sungem,netdev=mynet0";
                    print(self.shell(command));
                    
                    self.isRunning = false;
                }
            }
        }
    }
    
    func escape(text: String) -> String {
        return text.replacingOccurrences(of: " ", with: "\\ ");
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
        super.viewDidLoad();
        
        vm = VirtualMachine(name:"tiger", displayName: "Mac OS X Tiger", memory: 2048, resolution: "1440x900x32", bootArg: "c");
        let drive = VirtualDrive(name:"tiger", format: "qcow2", mediaType: "disk");
        vm?.addVirtualDrive(drive: drive);
        
        if let vm = self.vm {
            vmName.stringValue = vm.displayName;
            vmFilePath.stringValue = self.libraryPath + "/" + vm.displayName + ".qvm";
            vmResolution.stringValue = vm.resolution;
            vmMemory.stringValue = String(vm.memory / 1024) + " GB";
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

