//
//  Shell.swift
//  MacMulator
//
//  Created by Vale on 03/02/21.
//

import Foundation

class Shell {
    let task = Process()
    let pipe = Pipe()
    
    func runCommand(_ command: String) -> String {
        
        print("Running " + command);
        do {
            try ObjC.catchException({
                if (!self.task.isRunning) {
                    self.task.standardOutput = self.pipe
                    self.task.arguments = ["-c", command]
                    self.task.launchPath = "/bin/zsh"
                    self.task.launch();
                }
            })
        } catch {
            print(error);
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        return output
    }
    
    func runAsyncCommand(_ command: String, uponCompletion callback: @escaping () -> Void) -> Void {
        DispatchQueue.global().async() {
            self.runCommand(command);
            do {
                try ObjC.catchException({
                    DispatchQueue.main.async {
                        callback();
                    }
                })
            } catch {
                print(error);
            }
        }
    }
    
    func setWorkingDir(_ path: String) {
        task.currentDirectoryPath = path;
    }
    
    func isRunning() -> Bool {
        return task.isRunning;
    }
    
    func waitForCommand() {
        task.waitUntilExit();
    }
}
