//
//  DiskImageManager.swift
//  MacMulator
//
//  Created by Vale on 22/10/26.
//

import Foundation

protocol DiskImageManager {
    func createDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, uponCompletion callback: @escaping (Int32, String?) -> Void)

    /// `progress`, when supported by the implementation, is called with the completion percentage (0-100) while converting.
    func convertDiskImage(_ virtualDrive: VirtualDrive, _ path: String, fromFormat oldFormat: String, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func getDiskImageInfo(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void)
}

extension DiskImageManager {
    func updateDiskImage(oldVirtualDrive: VirtualDrive, newVirtualDrive: VirtualDrive, path: String, progress: ((Double) -> Void)? = nil, uponCompletion callback: @escaping (Int32, String?) -> Void) {
        let resizeIfNeeded: (Int32) -> Void = { terminationCode in
            guard terminationCode == 0, newVirtualDrive.size != oldVirtualDrive.size else {
                callback(terminationCode, "Resize failed, or no resize needed.")
                return
            }
            self.resizeDiskImage(newVirtualDrive, path, shrink: newVirtualDrive.size < oldVirtualDrive.size, uponCompletion: callback)
        }

        if newVirtualDrive.format != oldVirtualDrive.format {
            convertDiskImage(newVirtualDrive, path, fromFormat: oldVirtualDrive.format, progress: progress, uponCompletion: callback)
        } else {
            resizeIfNeeded(0)
        }
    }
}
