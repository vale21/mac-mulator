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
            VZVirtioGraphicsScanoutConfiguration(widthInPixels: witdh, heightInPixels: height)
        ]

        return graphicsConfiguration
    }
    
    static func createBlockDeviceConfiguration(path: String) -> VZVirtioBlockDeviceConfiguration {
        do {
            let diskImageAttachment = try VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: path), readOnly: false);
            let disk = VZVirtioBlockDeviceConfiguration(attachment: diskImageAttachment)
            return disk
        } catch {
            fatalError("Failed to create Disk image: " + error.localizedDescription)
        }
    }
    
    static func createNetworkDeviceConfiguration() -> VZVirtioNetworkDeviceConfiguration {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()

        let networkAttachment = VZNATNetworkDeviceAttachment()
        networkDevice.attachment = networkAttachment
        networkDevice.macAddress = VZMACAddress.randomLocallyAdministered()
        return networkDevice
    }
    
    static func createPointingDeviceConfiguration() -> VZUSBScreenCoordinatePointingDeviceConfiguration {
        return VZUSBScreenCoordinatePointingDeviceConfiguration()
    }

    static func createKeyboardConfiguration() -> VZUSBKeyboardConfiguration {
        return VZUSBKeyboardConfiguration()
    }

    static func createAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
        let audioConfiguration = VZVirtioSoundDeviceConfiguration()

        let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
        inputStream.source = VZHostAudioInputStreamSource()

        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()

        audioConfiguration.streams = [inputStream, outputStream]
        return audioConfiguration
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
    
    static func createUSBMassStorageDeviceConfiguration(_ installMedia: String) -> VZUSBMassStorageDeviceConfiguration {
        guard let intallerDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: installMedia), readOnly: true) else {
            fatalError("Failed to create installer's disk attachment.")
        }

        return VZUSBMassStorageDeviceConfiguration(attachment: intallerDiskAttachment)
    }
}
