//
//  VirtualizationFrameworkUtils.swift
//  MacMulator
//
//  Created by Vale on 27/06/23.
//

import Foundation

class VirtualizationFrameworkUtils {
    @available(macOS 16.0, *)
    static func createASIFDiskImage(path: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32) -> Void) {
        let shell = Shell()
        let drivePath = path + "/" + virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION
        let command = "/usr/sbin/diskutil image create blank --fs none --format ASIF --size " + String(virtualDrive.size) + "GiB " + drivePath
        
        shell.runCommand(command, path, uponCompletion: callback)
    }

    static func createRAWDiskImage(path: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32) -> Void) {
        let drivePath = path + "/" + virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION
        let diskFd = open(drivePath, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        if diskFd == -1 {
            callback(-1)
        }

        var result = ftruncate(diskFd, Int64(virtualDrive.size) * 1024 * 1024 * 1024)
        if result != 0 {
            callback(-1)
        }

        result = close(diskFd)
        if result != 0 {
            callback(-1)
        }
        callback(0)
    }
}
