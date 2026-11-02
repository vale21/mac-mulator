//
//  QemuImgCommandBuilder.swift
//  MacMulator
//
//  Created by Vale on 05/02/21.
//

import Foundation

class QemuImgCommandBuilder {
    var qemuPath: String
    var executable: String = QemuConstants.QEMU_IMG
    var command: String?
    var format: String?
    var targetFormat: String?
    var size: String?
    var name: String?
    var targetName: String?
    var shrinkArg: Bool?
    var shortSize: String?
    var backingFile: String?
    var backingFormat: String?

    init(qemuPath: String) {
        self.qemuPath = qemuPath
    }

    func withCommand(_ command: String) -> QemuImgCommandBuilder {
        self.command = command
        return self
    }

    func withFormat(_ format: String) -> QemuImgCommandBuilder {
        self.format = format
        return self
    }

    func withTargetFormat(_ targetFormat: String) -> QemuImgCommandBuilder {
        self.targetFormat = targetFormat
        return self
    }

    func withSize(_ size: String) -> QemuImgCommandBuilder {
        self.size = size
        return self
    }

    func withName(_ name: String) -> QemuImgCommandBuilder {
        self.name = Utils.escape(name)
        return self
    }

    func withTargetName(_ targetName: String) -> QemuImgCommandBuilder {
        self.targetName = targetName
        return self
    }

    func withShrinkArg(_ shrinkArg: Bool) -> QemuImgCommandBuilder {
        self.shrinkArg = shrinkArg
        return self
    }

    func withBackingFile(_ backingFile: String) -> QemuImgCommandBuilder {
        self.backingFile = Utils.escape(backingFile)
        return self
    }

    func withBackingFormat(_ backingFormat: String) -> QemuImgCommandBuilder {
        self.backingFormat = backingFormat
        return self
    }

    func withShortSize(_ shortSize: String) -> QemuImgCommandBuilder {
        self.shortSize = shortSize
        return self
    }

    func build() -> String {
        var cmd = Utils.escape(qemuPath) + "/" + executable

        if let command {
            cmd += " " + command
        }
        if let format {
            cmd += " -f " + format
        }
        if let targetFormat {
            cmd += " -O " + targetFormat
        }
        if let backingFile {
            cmd += " -b " + backingFile
        }
        if let backingFormat {
            cmd += " -F " + backingFormat
        }
        if let size {
            cmd += " -o size=" + size
        }
        if let name {
            cmd += " " + name
        }
        if let targetName {
            cmd += " " + targetName
        }
        if let shrinkArg {
            cmd += shrinkArg ? " --shrink" : ""
        }
        if let shortSize {
            cmd += " " + shortSize
        }

        return cmd
    }
}
