/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Helper that creates various configuration objects exposed in the `VZVirtualMachineConfiguration`.
*/

import Foundation
import Virtualization

#if arch(arm64)

@available(macOS 12.0, *)
struct MacOSVirtualMachineConfigurationHelper {

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

    static func createNetworkDeviceConfiguration() -> VZVirtioNetworkDeviceConfiguration {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()

        let networkAttachment = VZNATNetworkDeviceAttachment()
        networkDevice.attachment = networkAttachment
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
}

#endif
