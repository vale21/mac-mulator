//
//  DiskImageManager.swift
//  MacMulator
//
//  Created by Vale on 22/10/26.
//

import Foundation

protocol DiskImageManager {
    func createDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32) -> Void)

    func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, uponCompletion callback: @escaping (Int32) -> Void)

    func convertDiskImage(_ virtualDrive: VirtualDrive, _ path: String, fromFormat oldFormat: String, uponCompletion callback: @escaping (Int32) -> Void)

    func getDiskImageInfo(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void)
}

extension DiskImageManager {
    func updateDiskImage(oldVirtualDrive: VirtualDrive, newVirtualDrive: VirtualDrive, path: String, uponCompletion callback: @escaping (Int32) -> Void) {
        let resizeIfNeeded: (Int32) -> Void = { terminationCode in
            guard terminationCode == 0, newVirtualDrive.size != oldVirtualDrive.size else {
                callback(terminationCode)
                return
            }
            self.resizeDiskImage(newVirtualDrive, path, shrink: newVirtualDrive.size < oldVirtualDrive.size, uponCompletion: callback)
        }

        if newVirtualDrive.format != oldVirtualDrive.format {
            convertDiskImage(newVirtualDrive, path, fromFormat: oldVirtualDrive.format, uponCompletion: resizeIfNeeded)
        } else {
            resizeIfNeeded(0)
        }
    }
}
