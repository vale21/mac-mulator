/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Helper that creates various configuration objects exposed in the `VZVirtualMachineConfiguration`.
*/

import Foundation
import Virtualization

#if arch(arm64)

@available(macOS 12.0, *)
class MacOSVirtualMachineConfigurationHelper {

    static func createBootLoader() -> VZMacOSBootLoader {
        return VZMacOSBootLoader()
    }

    static func createGraphicsDeviceConfiguration(witdh: Int, height: Int, ppi: Int) -> VZMacGraphicsDeviceConfiguration {
        let graphicsConfiguration = VZMacGraphicsDeviceConfiguration()
        graphicsConfiguration.displays = [
            VZMacGraphicsDisplayConfiguration(widthInPixels: witdh, heightInPixels: height, pixelsPerInch: ppi)
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

    static func createNetworkDeviceConfiguration(macAddress: String) -> VZVirtioNetworkDeviceConfiguration {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()

        let networkAttachment = VZNATNetworkDeviceAttachment()
        networkDevice.attachment = networkAttachment
        networkDevice.macAddress = VZMACAddress(string: macAddress)!
        return networkDevice
    }

    static func createPointingDeviceConfigurations(vm: VirtualMachine) -> [ VZPointingDeviceConfiguration ] {
        if #available(macOS 13.0, *), Utils.isTrackpadSupported(vm) {
            return [ VZMacTrackpadConfiguration() ]
        } else {
            return [ VZUSBScreenCoordinatePointingDeviceConfiguration() ]
        }
    }

    static func createKeyboardConfiguration(vm: VirtualMachine) -> VZKeyboardConfiguration {
        if #available(macOS 14.0, *), Utils.isMacKeyboardSupported(vm) {
            return VZMacKeyboardConfiguration()
        } else {
            return VZUSBKeyboardConfiguration()
        }
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
}

#endif
