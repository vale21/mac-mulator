/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Download the latest macOS restore image from the network.
*/

import Foundation
import Virtualization

@available(macOS 12.0, *)
class MacOSRestoreImage: NSObject {
    private var downloadObserver: NSKeyValueObservation?
    private var vmCreator: VMCreator
    private var vm: VirtualMachine

    init(_ vmCreator: VMCreator, _ vm: VirtualMachine) {
        self.vmCreator = vmCreator
        self.vm = vm
    }
    
    #if arch(arm64)

    public func download(completionHandler: @escaping () -> Void) {
        NSLog("Attempting to download latest available restore image.")
        VZMacOSRestoreImage.fetchLatestSupported { [self](result: Result<VZMacOSRestoreImage, Error>) in
            switch result {
                case let .failure(error):
                    fatalError(error.localizedDescription)

                case let .success(restoreImage):
                    downloadRestoreImage(restoreImage: restoreImage, completionHandler: completionHandler)
            }
        }
    }

    private func downloadRestoreImage(restoreImage: VZMacOSRestoreImage, completionHandler: @escaping () -> Void) {
        let downloadTask = URLSession.shared.downloadTask(with: restoreImage.url) { localURL, response, error in
            if let error = error {
                fatalError("Download failed. \(error.localizedDescription).")
            }

            guard (try? FileManager.default.moveItem(at: localURL!, to: URL.init(fileURLWithPath: self.vm.path + "/" + VirtualizationFrameworkMacOSSupport.RESTORE_IMAGE_NAME))) != nil else {
                fatalError("Failed to move downloaded restore image to \(URL.init(fileURLWithPath: self.vm.path + "/" + VirtualizationFrameworkMacOSSupport.RESTORE_IMAGE_NAME)).")
            }

            completionHandler()
        }

        downloadObserver = downloadTask.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
            NSLog("Restore image download progress: \(change.newValue! * 100).")
            self.vmCreator.setProgress(change.newValue! * 100)
        }
        downloadTask.resume()
    }
    
    #endif
}
