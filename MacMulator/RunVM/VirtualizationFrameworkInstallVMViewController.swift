//
//  VirtualizationFrameworkInstallVMViewController.swift
//  MacMulator
//
//  Created by Vale on 15/08/22.
//

import Cocoa
import Virtualization

@available(macOS 12.0, *)
class VirtualizationFrameworkInstallVMViewController: NSViewController {
    
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var estimateTimeRemainingLabel: NSTextField!
    
    var progress: Double = 0.0
    var virtualMachine: VZVirtualMachine?
    var restoreImageURL: URL?
    var parentRunner: VirtualizationFrameworkVirtualMachineRunner?
    
    func setVirtualMachine(_ virtualMachine: VZVirtualMachine) {
        self.virtualMachine = virtualMachine
    }
    
    func setRestoreImageURL(_ restoreImageURL: URL) {
        self.restoreImageURL  = restoreImageURL
    }
    
    func setParentRunner(_ parentRunner: VirtualizationFrameworkVirtualMachineRunner) {
        self.parentRunner = parentRunner
    }
    
    override func viewDidLoad() {
        self.descriptionLabel.stringValue = "Installing macOS on the Virtual Machine. The process will start in a moment..."
        self.estimateTimeRemainingLabel.stringValue = "Estimate time remaining: Calculating..."
        
        progressBar.isIndeterminate = false
        progressBar.doubleValue = 0
        progressBar.minValue = 0
        progressBar.maxValue = 100
    }
    
#if arch(arm64)
    
    fileprivate func isComplete() -> Bool {
        return progress >= 100.0
    }
    
    override func viewDidAppear() {
        if let virtualMachine = virtualMachine {
            if let restoreImageURL = restoreImageURL {
                DispatchQueue.main.async {
                    let installer = VZMacOSInstaller(virtualMachine: virtualMachine, restoringFromImageAt: restoreImageURL)
                    
                    print("Starting installation.")
                    installer.install(completionHandler: { (result: Result<Void, Error>) in
                        if case let .failure(error) = result {
                            print("Installation failed with error: " + error.localizedDescription)
                        } else {
                            print("Installation succeeded.")
                        }
                        
                        virtualMachine.stop(completionHandler: { err in
                            self.dismiss(self)
                            self.parentRunner?.instllationComplete(result)
                        })
                    })
                    
                    let startTime = Int64(Date().timeIntervalSince1970)
                    Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
                        
                        _ = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
                            self.progress = change.newValue! * 100
                            print("Installation progress: \(self.progress).")
                        }
                        
                        
                        let currentValue = self.progressBar.doubleValue
                        if (currentValue <= 0) {
                            self.descriptionLabel.stringValue = "Installing macOS on the Virtual Machine. The process will start in a moment..."
                            self.estimateTimeRemainingLabel.stringValue = "Estimate time remaining: Calculating..."
                        } else {
                            self.descriptionLabel.stringValue = "Installing macOS on the Virtual Machine (" + String(Int(self.progress)) + "%)..."
                            self.estimateTimeRemainingLabel.stringValue = "Estimate time remaining: " + Utils.computeTimeRemaining(startTime: startTime, progress: self.progress)
                        }
                        if (self.progress > currentValue) {
                            let delta = self.progress - currentValue;
                            self.progressBar.increment(by: delta)
                        }
                        if (self.isComplete()) {
                            timer.invalidate()
                        }
                    });
                }
            }
        }
    }
    
#endif
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.progress = 100.0
        
        self.dismiss(self)
        self.parentRunner?.stopVM()
    }
}
