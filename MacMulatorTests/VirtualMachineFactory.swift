//
//  VirtualMachineFactory.swift
//  MacMulatorTests
//

import Foundation
@testable import MacMulator

enum VirtualMachineFactory {
    static func makeVirtualMachine(os: String = QemuConstants.OS_MAC,
                                   subtype: String = QemuConstants.SUB_MAC_BIG_SUR,
                                   architecture: String = QemuConstants.ARCH_ARM64,
                                   type: String = MacMulatorConstants.QEMU_VM,
                                   bootMode: String = QemuConstants.BOOT_UEFI,
                                   drives: [VirtualDrive] = []) -> VirtualMachine
    {
        let vm = VirtualMachine(os: os, subtype: subtype, architecture: architecture, path: "", displayName: "", description: "", memory: 1, cpus: 1, displayResolution: "", displayOrigin: QemuConstants.ORIGIN, networkDevice: QemuConstants.NETWORK_VMXNET3, physicalBridgeNetworkDevice: nil, videoDevice: QemuConstants.VGA_VIRTIO_GPU, qemuDisplay: QemuConstants.DISPLAY_DEFAULT, enable3DAcceleration: false, enableSpiceDisplay: false, hvf: false, macAddress: nil, type: type, bootMode: bootMode)
        drives.forEach(vm.addVirtualDrive)
        return vm
    }

    static func makeDrive(name: String, mediaType: String) -> VirtualDrive {
        VirtualDrive(path: "", name: name, format: QemuConstants.FORMAT_RAW, mediaType: mediaType, size: 0)
    }
}
