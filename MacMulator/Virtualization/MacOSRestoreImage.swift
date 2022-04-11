/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Download the latest macOS restore image from the network.
*/

import Foundation
import Virtualization

#if arch(arm64)

@available(macOS 12.0, *)
class MacOSRestoreImage: NSObject {
    
    private var downloadObserver: NSKeyValueObservation?

    // MARK: Observe the download progress

    public func download(path: String, completionHandler: @escaping (URL) -> Void) {
        NSLog("Attempting to download latest available restore image.")
        VZMacOSRestoreImage.fetchLatestSupported { [self](result: Result<VZMacOSRestoreImage, Error>) in
            switch result {
                case let .failure(error):
                    fatalError(error.localizedDescription)

                case let .success(restoreImage):
                downloadRestoreImage(path: path, restoreImage: restoreImage, completionHandler: completionHandler)
            }
        }
    }

    // MARK: Download the Restore Image from the network

    private func downloadRestoreImage(path: String, restoreImage: VZMacOSRestoreImage, completionHandler: @escaping (URL) -> Void) {
        let downloadTask = URLSession.shared.downloadTask(with: restoreImage.url) { localURL, response, error in
            if let error = error {
                fatalError("Download failed. \(error.localizedDescription).")
            }

            let installerURL = URL(fileURLWithPath: path + "/macOSInstaller.ipsw");
            guard (try? FileManager.default.moveItem(at: localURL!, to: installerURL)) != nil else {
                fatalError("Failed to move downloaded restore image to \(installerURL).")
            }

            completionHandler(installerURL)
        }

        downloadObserver = downloadTask.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
            NSLog("Restore image download progress: \(change.newValue! * 100).")
        }
        downloadTask.resume()
    }
}

#endif
