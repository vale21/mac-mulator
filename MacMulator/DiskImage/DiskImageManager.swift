//
//  DiskImageManager.swift
//  MacMulator
//
//  Created by Vale on 22/10/26.
//

import Foundation

protocol DiskImageManager {
    func createDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void)

    /// Creates `virtualDrive` as an overlay layer on top of `backingDrive`, which is left untouched.
    func createLinkedDiskImage(_ virtualDrive: VirtualDrive, backingDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void)

    /// Merges a linked drive with the template layers beneath it into a standalone image, replacing the drive file in place.
    /// The template drive is left untouched. The caller is responsible for clearing `backingPath` afterwards.
    func flattenLinkedDiskImage(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String?) -> Void)

    func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, progress: ((Double) -> Void)?, uponCompletion callback: @escaping (Int32, String?) -> Void)

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
            self.resizeDiskImage(newVirtualDrive, path, shrink: newVirtualDrive.size < oldVirtualDrive.size, progress: progress, uponCompletion: callback)
        }

        if newVirtualDrive.format != oldVirtualDrive.format {
            // Overlay layers depend on the format of the drive they sit on, so they can't be converted.
            guard !oldVirtualDrive.isLinked else {
                callback(-1, NSLocalizedString("DiskImageManager.convertLinkedFailed", comment: ""))
                return
            }
            convertDiskImage(newVirtualDrive, path, fromFormat: oldVirtualDrive.format, progress: progress, uponCompletion: { terminationCode, errorMessage in
                guard terminationCode == 0 else {
                    callback(terminationCode, errorMessage)
                    return
                }
                resizeIfNeeded(0)
            })
        } else {
            resizeIfNeeded(0)
        }
    }
}
