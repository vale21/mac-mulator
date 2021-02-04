//
//  QemuRunner.swift
//  MacMulator
//
//  Created by Vale on 03/02/21.
//

import Foundation

class QemuRunner {
    
    var listenPort: Int32 = 4444;
    let shell = Shell();
    let qemuPath: String;
    
    init() {
        qemuPath = UserDefaults.standard.string(forKey: "qemuPath") ?? "";
    }
    
    func createDiskImage(path: String, virtualDrive: VirtualDrive) {
        shell.setWorkingDir(path);
        
        let command: String = qemuPath
            + "/qemu-img create -f " + virtualDrive.format + " -o size=" + String(virtualDrive.size) + "G " + virtualDrive.name + ".qcow2 ";
        shell.runCommand(command);
    }
    
    func runVM(virtualMachine: VirtualMachine, uponCompletion callback: @escaping (VirtualMachine) -> Void) {
        var command: String = qemuPath
            + "/qemu-system-ppc -L pc-bios -boot " + virtualMachine.bootArg + " -M mac99,via=pmu -m " + String(virtualMachine.memory)
            + " -g " + virtualMachine.displayResolution + " -prom-env 'auto-boot?=true' -prom-env 'vga-ndrv?=true'";
        
        for drive in virtualMachine.drives {
            command += (" -drive file=" + drive.path + ",format=" + drive.format + ",media=" + drive.mediaType);
        }
        command += " -netdev user,id=mynet0 -device sungem,netdev=mynet0 -qmp tcp:localhost:" + String(listenPort) + ",server,nowait";
        shell.runAsyncCommand(command, uponCompletion: {
            callback(virtualMachine);
        });
        
        if (virtualMachine.isNew) {
            virtualMachine.isNew = false;
            virtualMachine.bootArg = "c";
            virtualMachine.writeToPlist();
        }
    }
    
    func setListenPort(_ listenPort: Int32) {
        self.listenPort = listenPort;
    }
    
    func waitForCompletion() {
        shell.waitForCommand();
    }
    
    func isRunning() -> Bool {
        return shell.isRunning();
    }
}
