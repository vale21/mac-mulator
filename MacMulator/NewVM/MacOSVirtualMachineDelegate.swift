/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 A class that conforms to `VZVirtualMachineDelegate` and to track the virtual machine's state.
 */

import Foundation
import Virtualization

@available(macOS 12.0, *)
class MacOSVirtualMachineDelegate: NSObject, VZVirtualMachineDelegate {
    func virtualMachine(_: VZVirtualMachine, didStopWithError error: Error) {
        NSLog(String(format: NSLocalizedString("MacOSVirtualMachineDelegate.stoppedWithError", comment: ""), error.localizedDescription))
        exit(-1)
    }

    func guestDidStop(_: VZVirtualMachine) {
        NSLog(NSLocalizedString("MacOSVirtualMachineDelegate.stoppedByGuest", comment: ""))
        exit(0)
    }
}
