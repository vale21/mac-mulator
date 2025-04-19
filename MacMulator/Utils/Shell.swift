//
//  Shell.swift
//  MacMulator
//
//  Created by Vale on 03/02/21.
//

import Foundation

class Shell {
    let task = Process()
    let pipe_out = Pipe()
    let pipe_err = Pipe()
    let pipe_in = Pipe()

    var stdout: String = ""
    var stderr: String = ""
    var output: String = ""

    private func setupStandardOutput() {
        task.standardOutput = pipe_out
        pipe_out.fileHandleForReading.readabilityHandler = { fileHandle in
            let availableData = fileHandle.availableData
            let newOutput = String(data: availableData, encoding: .utf8)
            if let out = newOutput, !out.isEmpty {
                self.stdout.append(contentsOf: out)
                self.output.append(contentsOf: out)
            }
        }
    }

    private func setupStandardError() {
        task.standardError = pipe_err
        pipe_err.fileHandleForReading.readabilityHandler = { fileHandle in
            let availableData = fileHandle.availableData
            let newOutput = String(data: availableData, encoding: .utf8)
            if let out = newOutput, !out.isEmpty {
                self.stderr.append(contentsOf: out)
                self.output.append(contentsOf: out)
            }
        }
    }

    func runCommand(_ command: String, _ currentDirectoryPath: String, uponCompletion callback: @escaping (Int32) -> Void) {
        DispatchQueue.global().async {
            self.task.currentDirectoryPath = currentDirectoryPath
            print("Running " + command + " in " + self.task.currentDirectoryPath)
            do {
                if !self.task.isRunning {
                    self.setupStandardOutput()
                    self.setupStandardError()

                    self.task.arguments = ["-c", command]
                    self.task.launchPath = "/bin/zsh"

                    self.task.terminationHandler = { _ in
                        self.pipe_err.fileHandleForReading.readabilityHandler = nil
                        self.pipe_out.fileHandleForReading.readabilityHandler = nil
                        self.pipe_in.fileHandleForWriting.writeabilityHandler = nil

                        callback(self.task.terminationStatus)
                    }
                    try self.task.run()
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func isRunning() -> Bool {
        task.isRunning
    }

    func kill() {
        task.terminate()
    }

    func waitForCommand() {
        task.waitUntilExit()
    }

    func writeToStandardInput(_ command: String) {
        if let data = command.data(using: .utf8) {
            pipe_in.fileHandleForWriting.write(data)
        }
    }

    func readFromStandardOutput() -> String {
        stdout
    }

    func readFromStandardError() -> String {
        stderr
    }

    func readFromConsole() -> String {
        output
    }
}
