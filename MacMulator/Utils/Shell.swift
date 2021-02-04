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
        
        task.standardOutput = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        return output
    }
    
    func runAsyncCommand(_ command: String, uponCompletion callback: @escaping () -> Void) -> Void {
        DispatchQueue.global().async() {
            self.runCommand(command);
            print("Terminated? :" + String(self.task.isRunning));
            print("Exit status: " + String(self.task.terminationStatus));
            if (self.task.terminationStatus == 0) {
                callback();
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
