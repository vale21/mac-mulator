//
//  WorkspaceState.swift
//  MacMulator
//

import Foundation

/// State of the MacMulator workspace folder (the folder chosen in Preferences): the list of saved VMs and the
/// preferences. It is persisted in a hidden plist inside the workspace folder. Only the path of the workspace folder
/// itself stays in UserDefaults, since it is needed to find the file.
///
/// The state file is kept open and locked while in use, so that two instances of MacMulator can not work on the same
/// workspace. The lock is released by the system when the app quits or crashes.
final class WorkspaceState {
    static let shared = WorkspaceState()

    /// Outcome of trying to lock the state file of a workspace.
    enum LockResult {
        case locked(FileHandle)
        case inUse
        case failed(String)
    }

    /// Keys of the values that used to live in UserDefaults and are now stored in the state file.
    private static let legacyKeys = [
        MacMulatorConstants.PREFERENCE_KEY_SAVED_VMS,
        MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH,
        MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_RATE,
        MacMulatorConstants.PREFERENCE_KEY_LIVE_PREVIEW_ENABLED,
    ]

    /// The locked state file of the workspace in use. Nil until a workspace is opened: nothing is saved meanwhile.
    private var fileHandle: FileHandle?
    private(set) var filePath: String = ""

    var savedVMs: [String] = []
    var qemuPath: String = Utils.getDefaultQemuFolderPath()
    var livePreviewRate: Int = 10
    var livePreviewEnabled: Bool = false

    private init() {}

    /// Opens (creating it if needed) and locks the state file at the given path, without switching to it.
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

    /// Switches to the state file locked by `lockStateFile(atPath:)`, releasing the previous one, and loads its content.
    func open(_ handle: FileHandle, atPath path: String) {
        fileHandle = handle
        filePath = path
        load()
    }

    /// Loads the state from the locked file. Values missing from the file are taken from UserDefaults, where they used
    /// to be stored, and are then migrated to the file; otherwise defaults are used. A workspace folder without a state
    /// file therefore starts with no VMs and default preferences.
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

    /// Writes the state to the locked file. The file is rewritten in place: replacing it would drop the lock.
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
