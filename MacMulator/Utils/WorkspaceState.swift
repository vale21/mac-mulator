//
//  WorkspaceState.swift
//  MacMulator
//

import Foundation

final class WorkspaceState {
    static let shared = WorkspaceState()

    enum LockResult {
        case locked(FileHandle)
        case inUse
        case failed(String)
    }

    private static let legacyKeys = [
        MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS,
        MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH,
        MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE,
        MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED,
    ]

    private var fileHandle: FileHandle?
    private(set) var filePath: String = ""

    var savedVMs: [String] = []
    var qemuPath: String = Utils.getDefaultQemuFolderPath()
    var livePreviewRate: Int = 10
    var livePreviewEnabled: Bool = false

    private init() {}

    static func lockStateFile(atPath path: String) -> LockResult {
        do {
            try FileManager.default.createDirectory(atPath: Utils.getParentDir(path), withIntermediateDirectories: true)
        } catch {
            return .failed(error.localizedDescription)
        }

        let fd = Darwin.open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
        if fd < 0 {
            return .failed(String(cString: strerror(errno)))
        }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            let lockError = errno
            Darwin.close(fd)
            return lockError == EWOULDBLOCK ? .inUse : .failed(String(cString: strerror(lockError)))
        }
        return .locked(FileHandle(fileDescriptor: fd, closeOnDealloc: true))
    }

    func open(_ handle: FileHandle, atPath path: String) {
        fileHandle = handle
        filePath = path
        load()
    }

    private func load() {
        var state: [String: Any] = [:]
        do {
            try fileHandle?.seek(toOffset: 0)
            if let data = try fileHandle?.readToEnd(), !data.isEmpty {
                if let fileState = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                    state = fileState
                }
            }
        } catch {
            print("Could not read state file " + filePath + ": " + error.localizedDescription)
        }

        let userDefaults = UserDefaults.standard
        var migrated = false
        for key in WorkspaceState.legacyKeys where state[key] == nil {
            if let legacyValue = userDefaults.object(forKey: key) {
                state[key] = legacyValue
                migrated = true
            }
        }

        savedVMs = state[MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS] as? [String] ?? []
        qemuPath = state[MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH] as? String ?? Utils.getDefaultQemuFolderPath()
        livePreviewRate = state[MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE] as? Int ?? 10
        livePreviewEnabled = state[MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED] as? Bool ?? false

        if migrated, save() {
            for key in WorkspaceState.legacyKeys {
                userDefaults.removeObject(forKey: key)
            }
        }
    }

    @discardableResult
    func save() -> Bool {
        guard let fileHandle else { return false }
        let state: [String: Any] = [
            MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS: savedVMs,
            MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH: qemuPath,
            MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE: livePreviewRate,
            MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED: livePreviewEnabled,
        ]
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: state, format: .xml, options: 0)
            try fileHandle.truncate(atOffset: 0)
            try fileHandle.write(contentsOf: data)
            try fileHandle.synchronize()
            return true
        } catch {
            print("Could not write state file " + filePath + ": " + error.localizedDescription)
            return false
        }
    }
}
