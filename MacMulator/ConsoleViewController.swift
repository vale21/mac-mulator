//
//  ConsoleViewController.swift
//  MacMulator
//
//  Created by Vale on 10/08/21.
//

import Cocoa

class ConsoleViewController: NSViewController {

    @IBOutlet var consoleView: NSTextView!
    
    var rootController: RootViewController?;
    var isVisible: Bool = false;
    
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    override func viewWillAppear() {
        self.isVisible = true;
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { timer in
            if !self.isVisible {
                timer.invalidate();
            } else {
                if let rootController = self.rootController, rootController.isCurrentVMRunning(), let runner = rootController.getRunnerForCurrentVM() {
                    self.consoleView.string = runner.getConsoleOutput();
                    self.consoleView.scrollToEndOfDocument(self);
                } else {
                    self.consoleView.string = NSLocalizedString("ConsoleViewController.vmNotRunning", comment: "")
                    timer.invalidate();
                }
            }
        });
    }
    
    override func viewWillDisappear() {
        self.isVisible = false;
    }
}
