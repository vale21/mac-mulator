//
//  QemuCapabilitiesReporter.swift
//  MacMulator
//
//  Created by Vale on 14/10/2026.
//

import Foundation

class QemuCapabilitiesReporter {
    let qemuVersion: String

    let spiceSupported: Bool
    let virGLSupported: Bool
    let appleParavirtualizedGraphicsSupported: Bool

    let vmnetSupported: Bool

    let hasX86Binary: Bool
    let hasx86_64Binary: Bool
    let hasArmBinary: Bool
    let hasAarch64Binary: Bool
    let hasRiscvBinary: Bool
    let hasRiscv64Binary: Bool
    let hasPowerPCBinary: Bool
    let hasPowerPC64Binary: Bool
    let hasM68kBinary: Bool
    let hasQemuImgBinary: Bool
    let hasSwtpmBinary: Bool

    let availableDisplays: [String]
    let availableVideoDevices: [String]
    let availableNetworkDevices: [String]

    init(qemuVersion: String, spiceSupported: Bool, virGLSupported: Bool, appleParavirtualizedGraphicsSupported: Bool, vmnetSupported: Bool, hasX86Binary: Bool, hasx86_64Binary: Bool, hasArmBinary: Bool, hasAarch64Binary: Bool, hasRiscvBinary: Bool, hasRiscv64Binary: Bool, hasPowerPCBinary: Bool, hasPowerPC64Binary: Bool, hasM68kBinary: Bool, hasQemuImgBinary: Bool, hasSwtpmBinary: Bool, availableDisplays: [String], availableVideoDevices: [String], availableNetworkDevices: [String]) {
        self.qemuVersion = qemuVersion
        self.spiceSupported = spiceSupported
        self.virGLSupported = virGLSupported
        self.appleParavirtualizedGraphicsSupported = appleParavirtualizedGraphicsSupported
        self.vmnetSupported = vmnetSupported
        self.hasX86Binary = hasX86Binary
        self.hasx86_64Binary = hasx86_64Binary
        self.hasArmBinary = hasArmBinary
        self.hasAarch64Binary = hasAarch64Binary
        self.hasRiscvBinary = hasRiscvBinary
        self.hasRiscv64Binary = hasRiscv64Binary
        self.hasPowerPCBinary = hasPowerPCBinary
        self.hasPowerPC64Binary = hasPowerPC64Binary
        self.hasM68kBinary = hasM68kBinary
        self.hasQemuImgBinary = hasQemuImgBinary
        self.hasSwtpmBinary = hasSwtpmBinary
        self.availableDisplays = availableDisplays
        self.availableVideoDevices = availableVideoDevices
        self.availableNetworkDevices = availableNetworkDevices
    }

    private static let cacheQueue = DispatchQueue(label: "QemuCapabilitiesReporter.cache")
    private static var INSTANCES: [String: QemuCapabilitiesReporter] = [:]
    private static var cachedCommands: [String: [String]] = [:]
    private static var availableBinaries: [String: [String: Bool]] = [:]

    static func getInstance(forQemuPath qemuPath: String) -> QemuCapabilitiesReporter? {
        cacheQueue.sync {
            loadInstance(forQemuPath: qemuPath)
        }
    }

    private static func loadInstance(forQemuPath qemuPath: String) -> QemuCapabilitiesReporter? {
        if INSTANCES.contains(where: { $0.key == qemuPath }) {
            return INSTANCES[qemuPath]
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: qemuPath) {
            let startTimestamp = Date()

            #if ENTHUSIAST
                let hasX86Binary = isBinaryAvailable(QemuConstants.ARCH_X86, qemuPath: qemuPath)
                print("x86 binary found: \(hasX86Binary)")
            #else
                let hasX86Binary = true
            #endif

            #if ENTHUSIAST
                let hasx86_64Binary = isBinaryAvailable(QemuConstants.ARCH_X64, qemuPath: qemuPath)
                print("x86 64 binary found: \(hasx86_64Binary)")
            #else
                let hasx86_64Binary = true
            #endif

            #if ENTHUSIAST
                let hasArmBinary = isBinaryAvailable(QemuConstants.ARCH_ARM, qemuPath: qemuPath)
                print("ARM binary found: \(hasArmBinary)")
            #else
                let hasArmBinary = true
            #endif

            #if ENTHUSIAST
                let hasAarch64Binary = isBinaryAvailable(QemuConstants.ARCH_ARM64, qemuPath: qemuPath)
                print("ARM 64 binary found: \(hasAarch64Binary)")
            #else
                let hasAarch64Binary = true
            #endif

            #if ENTHUSIAST
                let hasPowerPCBinary = isBinaryAvailable(QemuConstants.ARCH_PPC, qemuPath: qemuPath)
                print("PowerPC binary found: \(hasPowerPCBinary)")
            #else
                let hasPowerPCBinary = true
            #endif

            #if ENTHUSIAST
                let hasPowerPC64Binary = isBinaryAvailable(QemuConstants.ARCH_PPC64, qemuPath: qemuPath)
                print("PowerPC 64 binary found: \(hasPowerPC64Binary)")
            #else
                let hasPowerPC64Binary = true
            #endif

            #if ENTHUSIAST
                let hasRiscvBinary = isBinaryAvailable(QemuConstants.ARCH_RISCV32, qemuPath: qemuPath)
                print("RISCV binary found: \(hasRiscvBinary)")
            #else
                let hasRiscvBinary = true
            #endif

            #if ENTHUSIAST
                let hasRiscv64Binary = isBinaryAvailable(QemuConstants.ARCH_RISCV64, qemuPath: qemuPath)
                print("RISCV 64 binary found: \(hasRiscv64Binary)")
            #else
                let hasRiscv64Binary = true
            #endif

            #if ENTHUSIAST
                let hasM68kBinary = isBinaryAvailable(QemuConstants.ARCH_68K, qemuPath: qemuPath)
                print("m68k 64 binary found: \(hasM68kBinary)")
            #else
                let hasM68kBinary = true
            #endif

            #if ENTHUSIAST
                let hasQemuImgBinary = isBinaryAvailable(QemuConstants.QEMU_IMG, qemuPath: qemuPath)
                print("qemu-img binary found: \(hasQemuImgBinary)")
            #else
                let hasQemuImgBinary = true
            #endif

            #if ENTHUSIAST
                let hasSwtpmBinary = isBinaryAvailable(QemuConstants.SWTPM, qemuPath: qemuPath)
                print("swtpm binary found: \(hasSwtpmBinary)")
            #else
                let hasSwtpmBinary = true
            #endif

            availableBinaries[qemuPath] = [
                QemuConstants.ARCH_X86: hasX86Binary,
                QemuConstants.ARCH_X64: hasx86_64Binary,
                QemuConstants.ARCH_ARM: hasArmBinary,
                QemuConstants.ARCH_ARM64: hasAarch64Binary,
                QemuConstants.ARCH_PPC: hasPowerPCBinary,
                QemuConstants.ARCH_PPC64: hasPowerPC64Binary,
                QemuConstants.ARCH_RISCV32: hasRiscvBinary,
                QemuConstants.ARCH_RISCV64: hasRiscv64Binary,
                QemuConstants.ARCH_68K: hasM68kBinary,
            ]

            let qemuVersion = verifyQemuVersion(forQemuPath: qemuPath)
            print("Found QEMU version: \(qemuVersion)")

            #if ENTHUSIAST
                let virGLSupported = verifyOpenGLSupport(forQemuPath: qemuPath)
                print("OPENGL Supported: \(virGLSupported)")
            #else
                let virGLSupported = true
            #endif

            #if ENTHUSIAST
                let appleParavirtualizedGraphicsSupported = verifyParavirtualizedGraphicsSupport(forQemuPath: qemuPath)
                print("Apple Paravirtualized Graphics Supported: \(appleParavirtualizedGraphicsSupported)")
            #else
                let appleParavirtualizedGraphicsSupported = true
            #endif

            #if ENTHUSIAST
                let spiceSupported = verifySpiceSupport(forQemuPath: qemuPath)
                print("SPICE Supported: \(spiceSupported)")
            #else
                let spiceSupported = true
            #endif

            #if ENTHUSIAST
                let vmnetSupported = verifyVmnetSupport(forQemuPath: qemuPath)
                print("vmnet Supported: \(vmnetSupported)")
            #else
                let vmnetSupported = true
            #endif

            let availableDisplays = getDisplays(forQemuPath: qemuPath)
            print("Found displays: \(availableDisplays)")

            let availableVideoDevices = getVideoDevices(forQemuPath: qemuPath)
            print("Found video devices: \(availableVideoDevices)")

            let availableNetworkDevices = getNetworkDevices(forQemuPath: qemuPath)
            print("Found network devices: \(availableNetworkDevices)")

            INSTANCES[qemuPath] = QemuCapabilitiesReporter(qemuVersion: qemuVersion, spiceSupported: spiceSupported, virGLSupported: virGLSupported, appleParavirtualizedGraphicsSupported: appleParavirtualizedGraphicsSupported, vmnetSupported: vmnetSupported, hasX86Binary: hasX86Binary, hasx86_64Binary: hasx86_64Binary, hasArmBinary: hasArmBinary, hasAarch64Binary: hasAarch64Binary, hasRiscvBinary: hasRiscvBinary, hasRiscv64Binary: hasRiscv64Binary, hasPowerPCBinary: hasPowerPCBinary, hasPowerPC64Binary: hasPowerPC64Binary, hasM68kBinary: hasM68kBinary, hasQemuImgBinary: hasQemuImgBinary, hasSwtpmBinary: hasSwtpmBinary, availableDisplays: availableDisplays, availableVideoDevices: availableVideoDevices, availableNetworkDevices: availableNetworkDevices)

            let endTimestamp = Date()
            print("Time elapsed: \(endTimestamp.timeIntervalSince(startTimestamp) * 1000) milliseconds")

            return INSTANCES[qemuPath]
        } else {
            return nil
        }
    }

    private static func getQemuExecutable(forQemuPath qemuPath: String) -> String {
        let hostBinary = Utils.hostArchitecture() == QemuConstants.HOST_X86_64 ? QemuConstants.ARCH_X64 : QemuConstants.ARCH_ARM64
        let binaries = availableBinaries[qemuPath] ?? [:]

        if binaries[hostBinary] == true {
            return Utils.escape(qemuPath + "/" + hostBinary)
        }

        let fallbackOrder = [QemuConstants.ARCH_X64, QemuConstants.ARCH_ARM64, QemuConstants.ARCH_X86, QemuConstants.ARCH_ARM,
                             QemuConstants.ARCH_RISCV64, QemuConstants.ARCH_RISCV32, QemuConstants.ARCH_PPC64, QemuConstants.ARCH_PPC,
                             QemuConstants.ARCH_68K]
        if let binary = fallbackOrder.first(where: { binaries[$0] == true }) {
            return Utils.escape(qemuPath + "/" + binary)
        }

        return Utils.escape(qemuPath + "/" + hostBinary)
    }

    private static func verifyOpenGLSupport(forQemuPath qemuPath: String) -> Bool {
        let condition: (String) -> Bool = { devices in
            devices.contains(QemuConstants.VGA_VIRTIO_GPU_GL) || devices.contains(QemuConstants.VGA_VIRTIO_VGA_GL) || devices.contains(QemuConstants.VGA_VIRTIO_RAMFB_GL)
        }

        let qemuExecutable = getQemuExecutable(forQemuPath: qemuPath)
        let command = qemuExecutable + " -device help"
        return verifyFeatureSupport(forQemuPath: qemuPath, condition: condition, command: command)
    }

    private static func verifyParavirtualizedGraphicsSupport(forQemuPath qemuPath: String) -> Bool {
        let condition: (String) -> Bool = { devices in
            devices.contains(QemuConstants.VGA_APPLE_GFX_PCI) || devices.contains(QemuConstants.VGA_APPLE_GFX_MMIO)
        }

        let qemuExecutable = getQemuExecutable(forQemuPath: qemuPath)
        let command = qemuExecutable + " -device help"

        return verifyFeatureSupport(forQemuPath: qemuPath, condition: condition, command: command)
    }

    private static func verifySpiceSupport(forQemuPath qemuPath: String) -> Bool {
        let condition: (String) -> Bool = { options in
            options.contains("spice")
        }

        let qemuExecutable = getQemuExecutable(forQemuPath: qemuPath)
        let command = qemuExecutable + " -help"

        return verifyFeatureSupport(forQemuPath: qemuPath, condition: condition, command: command)
    }

    private static func verifyVmnetSupport(forQemuPath qemuPath: String) -> Bool {
        let condition: (String) -> Bool = { options in
            options.contains("vmnet-host") && options.contains("vmnet-shared") && options.contains("vmnet-bridged")
        }

        let qemuExecutable = getQemuExecutable(forQemuPath: qemuPath)
        let command = qemuExecutable + " -help"

        return verifyFeatureSupport(forQemuPath: qemuPath, condition: condition, command: command)
    }

    private static func verifyQemuVersion(forQemuPath qemuPath: String) -> String {
        // getQemuVersion completes on a background queue (or immediately), so block until it reports back.
        let semaphore = DispatchSemaphore(value: 0)
        var qemuVersion = ""
        QemuUtils.getQemuVersion(qemuPath: qemuPath, uponCompletion: {
            version in
            qemuVersion = version ?? ""
            semaphore.signal()
        })
        semaphore.wait()
        return qemuVersion
    }

    private static func getVideoDevices(forQemuPath qemuPath: String) -> [String] {
        getDevices(forQemuPath: qemuPath, deviceType: "Display devices")
    }

    private static func getNetworkDevices(forQemuPath qemuPath: String) -> [String] {
        getDevices(forQemuPath: qemuPath, deviceType: "Network devices")
    }

    private static func getSoundDevices(forQemuPath qemuPath: String) -> [String] {
        getDevices(forQemuPath: qemuPath, deviceType: "Sound devices")
    }

    private static func getDevices(forQemuPath qemuPath: String, deviceType: String) -> [String] {
        let parser: (String) -> [String] = { command in
            guard let range = command.range(of: deviceType + ":") else {
                return []
            }

            let devicesOutput = command[range.upperBound...]

            // The first component is the remainder of the "Display devices:" header line (empty),
            // so drop it before collecting device lines up to the next blank line.
            return devicesOutput
                .components(separatedBy: .newlines)
                .dropFirst()
                .prefix(while: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
                .compactMap { line in
                    guard let match = line.range(
                        of: #"^\s*name "([^"]+)""#,
                        options: .regularExpression
                    ) else {
                        return nil
                    }

                    let name = String(line[match])
                    return name
                        .replacingOccurrences(of: #"^\s*name ""#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #""$"#, with: "", options: .regularExpression)
                }
        }

        let qemuExecutable = getQemuExecutable(forQemuPath: qemuPath)
        let command = qemuExecutable + " -device help"

        return getFeaturesList(forQemuPath: qemuPath, parser: parser, command: command)
    }

    private static func getDisplays(forQemuPath qemuPath: String) -> [String] {
        let parser: (String) -> [String] = { command in
            guard let range = command.range(of: "Available display backend types:") else {
                return []
            }

            let displayOutput = command[range.upperBound...]

            // The first component is the remainder of the header line (empty),
            // then each line holds one display backend name up to the next blank line.
            return Array(displayOutput
                .components(separatedBy: .newlines)
                .dropFirst()
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .prefix(while: { !$0.isEmpty }))
        }

        let qemuExecutable = getQemuExecutable(forQemuPath: qemuPath)
        let command = qemuExecutable + " -display help"

        return getFeaturesList(forQemuPath: qemuPath, parser: parser, command: command)
    }

    private static func verifyFeatureSupport(forQemuPath qemuPath: String, condition: (String) -> Bool, command: String) -> Bool {
        condition(runCommand(command, forQemuPath: qemuPath))
    }

    private static func getFeaturesList(forQemuPath qemuPath: String, parser: (String) -> [String], command: String) -> [String] {
        parser(runCommand(command, forQemuPath: qemuPath))
    }

    private static func runCommand(_ command: String, forQemuPath qemuPath: String) -> String {
        if let cachedOutput = cachedCommands[command] {
            return cachedOutput.joined(separator: "\n")
        }

        print(command)
        // Shell completes on a background queue, so blocking the calling thread here cannot deadlock.
        let shell = Shell()
        let semaphore = DispatchSemaphore(value: 0)
        shell.runCommand(command, qemuPath, uponCompletion: { _, _ in
            semaphore.signal()
        })
        semaphore.wait()

        let output = shell.readFromStandardOutput()
        cachedCommands[command] = output.components(separatedBy: "\n")
        return output
    }

    private static func isBinaryAvailable(_ binary: String, qemuPath: String? = nil) -> Bool {
        let rootPath = qemuPath != nil ? qemuPath! : QemuUtils.getQemuPath()
        let fileManager = FileManager.default

        return fileManager.fileExists(atPath: rootPath + "/" + binary)
    }
}
