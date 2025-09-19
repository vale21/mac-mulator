//
//  LinuxVirtualMachineConfigurationHelper.swift
//  MacMulator
//
//  Created by Vale on 06/11/22.
//

import Foundation
import Virtualization

@available(macOS 13.0, *)
class LinuxVirtualMachineConfigurationHelper {
    static func createGraphicsDeviceConfiguration(witdh: Int, height: Int) -> VZVirtioGraphicsDeviceConfiguration {
        let graphicsConfiguration = VZVirtioGraphicsDeviceConfiguration()
        graphicsConfiguration.scanouts = [
            VZVirtioGraphicsScanoutConfiguration(widthInPixels: witdh, heightInPixels: height),
        ]

        return graphicsConfiguration
    }

    static func createBlockDeviceConfiguration(path: String) -> VZVirtioBlockDeviceConfiguration {
        do {
            let diskImageAttachment = try VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: path), readOnly: false)
            let disk = VZVirtioBlockDeviceConfiguration(attachment: diskImageAttachment)
            return disk
        } catch {
            fatalError("Failed to create Disk image: " + error.localizedDescription)
        }
    }

    static func createNetworkDeviceConfiguration(device: String, phisicalDevice: String?) -> VZVirtioNetworkDeviceConfiguration {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()

        var networkAttachment: VZNetworkDeviceAttachment = VZNATNetworkDeviceAttachment()
        if device == QemuConstants.ATTACHMENT_BRIDGED {
            let interfaces = VZBridgedNetworkInterface.networkInterfaces
            let interface = interfaces.first { $0.identifier == phisicalDevice } ?? interfaces[0]

            networkAttachment = VZBridgedNetworkDeviceAttachment(interface: interface)
        } else if device == QemuConstants.ATTACHMENT_VMNET {
            // networkAttachment = VZVmnetNetworkDeviceAttachment()
        }

        networkDevice.attachment = networkAttachment
        networkDevice.macAddress = VZMACAddress.randomLocallyAdministered()
        return networkDevice
    }

    static func createPointingDeviceConfiguration() -> VZUSBScreenCoordinatePointingDeviceConfiguration {
        VZUSBScreenCoordinatePointingDeviceConfiguration()
    }

    static func createKeyboardConfiguration() -> VZUSBKeyboardConfiguration {
        VZUSBKeyboardConfiguration()
    }

    static func createInputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
        let inputAudioDevice = VZVirtioSoundDeviceConfiguration()

        let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
        inputStream.source = VZHostAudioInputStreamSource()

        inputAudioDevice.streams = [inputStream]
        return inputAudioDevice
    }

    static func createOutputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
        let outputAudioDevice = VZVirtioSoundDeviceConfiguration()

        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()

        outputAudioDevice.streams = [outputStream]
        return outputAudioDevice
    }

    static func createSpiceAgentConsoleDeviceConfiguration() -> VZVirtioConsoleDeviceConfiguration {
        let consoleDevice = VZVirtioConsoleDeviceConfiguration()

        let spiceAgentPort = VZVirtioConsolePortConfiguration()
        spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
        let spice = VZSpiceAgentPortAttachment()
        spice.sharesClipboard = true
        spiceAgentPort.attachment = spice
        consoleDevice.ports[0] = spiceAgentPort

        return consoleDevice
    }

    static func createEFIVariableStore(path: String) -> VZEFIVariableStore {
        guard let efiVariableStore = try? VZEFIVariableStore(creatingVariableStoreAt: URL(fileURLWithPath: path)) else {
            fatalError("Failed to create the EFI variable store.")
        }

        return efiVariableStore
    }

    static func createUSBMassStorageDeviceConfiguration(_ path: String) -> VZUSBMassStorageDeviceConfiguration {
        guard let intallerDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: path), readOnly: true) else {
            fatalError("Failed to create installer's disk attachment.")
        }

        return VZUSBMassStorageDeviceConfiguration(attachment: intallerDiskAttachment)
    }

    @available(macOS 15.0, *)
    static func createUSBControllerConfiguration() -> VZUSBControllerConfiguration {
        VZXHCIControllerConfiguration()
    }
}
