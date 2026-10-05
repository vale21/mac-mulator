//
//  QemuSpiceViewerViewController.swift
//  MacMulator
//
//  Created by Vale on 05/10/2026.
//

import Cocoa
import CocoaSpiceNoUsb
import CocoaSpiceRenderer
import MetalKit

/// Shows the display of a running QEMU VM over SPICE and forwards keyboard and mouse input to it.
///
/// The VM has to be started with a SPICE server listening on a unix socket, for example
/// `-spice unix=on,addr=/tmp/debian.spice,disable-ticketing=on`.
class QemuSpiceViewerViewController: NSViewController {
    /// Path of the unix socket the SPICE server is listening on.
    var socketPath = "/tmp/debian.spice"

    private let displayView = SpiceDisplayView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    private let statusLabel = NSTextField(labelWithString: "")

    private var renderer: CSMetalRenderer?
    private var connection: CSConnection?
    private var display: CSDisplay?
    private var input: CSInput?
    private var displaySizeObservation: NSKeyValueObservation?
    private var windowResignKeyObserver: NSObjectProtocol?
    private var commandKeyUpMonitor: Any?
    private var agentSupportsMonitorsConfig = false
    private var lastErrorMessage: String?

    private var pressedMouseButtons: CSInputButton = []
    private var pressedModifierKeyCodes = Set<UInt16>()
    private var resolutionRequestTask: Task<Void, Never>?

    /// Task waiting for the socket to show up or for the next connection attempt
    private var connectTask: Task<Void, Never>?
    /// Connection attempts stop once this instant has passed. `nil` when no connection is being established
    private var connectionDeadline: Date?
    /// True once the main channel has been opened at least once on the current connection
    private var hasConnected = false

    /// How long to keep trying to reach the SPICE server before reporting a failure
    private static let connectionTimeout: TimeInterval = 30
    /// Pause between two consecutive socket checks or connection attempts
    private static let connectionRetryInterval: UInt64 = 500_000_000

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        displayView.translatesAutoresizingMaskIntoConstraints = false
        displayView.clearColor = MTLClearColorMake(0, 0, 0, 1)
        displayView.inputDelegate = self
        displayView.isHidden = true
        view.addSubview(displayView)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .white
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 0
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            displayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            displayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            displayView.topAnchor.constraint(equalTo: view.topAnchor),
            displayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])

        if displayView.device != nil {
            let metalRenderer = CSMetalRenderer(metalKitView: displayView)
            displayView.delegate = metalRenderer
            renderer = metalRenderer
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        view.window?.title = String(format: NSLocalizedString("QemuSpiceViewerViewController.windowTitle", comment: ""), socketPath)
        view.window?.makeFirstResponder(displayView)

        if let window = view.window, windowResignKeyObserver == nil {
            // Release every pressed key when the window loses focus so that no key stays stuck in the guest
            windowResignKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.releaseAllKeys()
                }
            }
        }

        if commandKeyUpMonitor == nil {
            // AppKit does not deliver keyUp to views while ⌘ is held down: catch those releases
            // before dispatch so that keys pressed as part of a ⌘ shortcut do not stay stuck in the guest
            commandKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
                guard let self, input != nil, event.modifierFlags.contains(.command),
                      event.window === self.view.window, view.window?.firstResponder === self.displayView
                else {
                    return event
                }
                sendKey(event.keyCode, pressed: false)
                return nil
            }
        }

        connect()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        if let observer = windowResignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            windowResignKeyObserver = nil
        }
        if let monitor = commandKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
            commandKeyUpMonitor = nil
        }
        disconnect()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateViewport()
    }

    // MARK: - Connection

    private func connect() {
        guard connection == nil else {
            return
        }
        guard renderer != nil else {
            showStatus(NSLocalizedString("QemuSpiceViewerViewController.noMetal", comment: ""))
            return
        }
        // CocoaSpice's GStreamer initialisation is written for the iOS sandbox and rewrites HOME,
        // TMPDIR and the XDG_* variables of the whole process from its worker thread. Wait for the
        // worker thread to be up, then undo that so the app and the processes it spawns (QEMU,
        // qemu-img) keep the environment they were launched with.
        let launchEnvironment = ProcessInfo.processInfo.environment
        guard CSMain.shared.spiceStart() else {
            showStatus(NSLocalizedString("QemuSpiceViewerViewController.spiceStartFailed", comment: ""))
            return
        }
        CSMain.shared.sync {}
        Self.restoreEnvironment(launchEnvironment)

        lastErrorMessage = nil
        hasConnected = false
        showStatus(String(format: NSLocalizedString("QemuSpiceViewerViewController.connecting", comment: ""), socketPath))

        // QEMU is usually still starting when the viewer is shown: keep trying for a while
        connectionDeadline = Date().addingTimeInterval(Self.connectionTimeout)
        attemptConnection()
    }

    /// Waits for the socket to exist, then opens a connection to it. Gives up once `connectionDeadline` has passed
    private func attemptConnection(after delay: UInt64 = 0) {
        connectTask?.cancel()
        connectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            // The socket is created by QEMU only once its SPICE server is listening
            while !Task.isCancelled, let self, !FileManager.default.fileExists(atPath: self.socketPath) {
                if connectionTimedOut {
                    failConnection()
                    return
                }
                try? await Task.sleep(nanoseconds: Self.connectionRetryInterval)
            }
            guard !Task.isCancelled, let self else {
                return
            }
            connectTask = nil
            openConnection()
        }
    }

    private func openConnection() {
        let newConnection = CSConnection(unixSocketFile: URL(fileURLWithPath: socketPath))
        newConnection.delegate = self
        connection = newConnection

        if !newConnection.connect() {
            connection = nil
            retryConnection()
        }
    }

    /// True while a connection is being established and no attempt has succeeded yet
    private var isConnecting: Bool {
        connectionDeadline != nil && !hasConnected
    }

    private var connectionTimedOut: Bool {
        guard let connectionDeadline else {
            return true
        }
        return Date() >= connectionDeadline
    }

    /// Schedules another attempt, or reports the failure if the deadline has passed
    private func retryConnection() {
        if connectionTimedOut {
            failConnection()
        } else {
            attemptConnection(after: Self.connectionRetryInterval)
        }
    }

    private func failConnection() {
        connectTask = nil
        connectionDeadline = nil
        showStatus(lastErrorMessage ?? String(format: NSLocalizedString("QemuSpiceViewerViewController.connectionFailed", comment: ""), socketPath))
    }

    private func disconnect() {
        connectTask?.cancel()
        connectTask = nil
        connectionDeadline = nil
        resolutionRequestTask?.cancel()
        resolutionRequestTask = nil
        releaseAllKeys()
        detachDisplay()
        // The connection is released in spiceDisconnected(_:), once SPICE confirms the disconnection
        connection?.disconnect()
    }

    private func showStatus(_ text: String?) {
        statusLabel.stringValue = text ?? ""
        statusLabel.isHidden = text == nil
    }

    /// Environment variables that CocoaSpice's `gst_ios_init()` overwrites.
    private static let environmentKeysChangedBySpice = [
        "HOME", "TMP", "TEMP", "TMPDIR",
        "XDG_RUNTIME_DIR", "XDG_CACHE_HOME", "XDG_DATA_DIRS", "XDG_CONFIG_DIRS", "XDG_CONFIG_HOME", "XDG_DATA_HOME",
        "FONTCONFIG_PATH", "CA_CERTIFICATES",
    ]

    /// Puts the variables listed in `environmentKeysChangedBySpice` back to the values they had in `environment`.
    private static func restoreEnvironment(_ environment: [String: String]) {
        for key in environmentKeysChangedBySpice {
            if let value = environment[key] {
                setenv(key, value, 1)
            } else {
                unsetenv(key)
            }
        }
    }

    // MARK: - Display

    private func attach(_ newDisplay: CSDisplay) {
        // Only a single display is supported: keep the first one that shows up
        guard display == nil, let renderer else {
            return
        }

        display = newDisplay
        newDisplay.addRenderer(renderer)
        displaySizeObservation = newDisplay.observe(\.displaySize, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.displaySizeChanged()
            }
        }

        displayView.isHidden = false
        showStatus(nil)
        displaySizeChanged()
    }

    private func detachDisplay() {
        displaySizeObservation = nil
        if let display, let renderer {
            display.removeRenderer(renderer)
        }
        display = nil
        displayView.isHidden = true
        displayView.hidesHostCursor = false
    }

    private func displaySizeChanged() {
        guard let display else {
            return
        }
        let size = display.displaySize
        guard size.width > 0, size.height > 0 else {
            return
        }
        fitWindow(to: size)
        updateViewport()
    }

    /// Resizes the window so that the guest display is shown 1:1 (in points), shrinking it when it does not fit on screen
    private func fitWindow(to displaySize: CGSize) {
        guard let window = view.window else {
            return
        }

        var target = displaySize
        if let screen = window.screen ?? NSScreen.main {
            let available = screen.visibleFrame.size
            let frame = window.frameRect(forContentRect: CGRect(origin: .zero, size: target))
            if frame.width > available.width || frame.height > available.height {
                let scale = min(available.width / frame.width, available.height / frame.height)
                target = CGSize(width: floor(displaySize.width * scale), height: floor(displaySize.height * scale))
            }
        }

        if view.bounds.size != target {
            window.setContentSize(target)
        }
    }

    /// Scales the guest framebuffer so that it fits the view, keeping its aspect ratio and centering it
    private func updateViewport() {
        guard let renderer, let display else {
            return
        }
        let drawable = displayView.drawableSize
        let size = display.displaySize
        guard drawable.width > 0, drawable.height > 0, size.width > 0, size.height > 0 else {
            return
        }

        renderer.viewportScale = min(drawable.width / size.width, drawable.height / size.height)
        renderer.viewportOrigin = .zero
        scheduleResolutionRequest()
    }

    /// Asks the guest (through the SPICE agent, when available) to adopt the view size as its resolution, debouncing window resizes
    private func scheduleResolutionRequest() {
        resolutionRequestTask?.cancel()
        guard agentSupportsMonitorsConfig else {
            return
        }
        resolutionRequestTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else {
                return
            }
            self?.requestGuestResolution()
        }
    }

    private func requestGuestResolution() {
        guard let display else {
            return
        }
        let wanted = CGSize(width: floor(view.bounds.width), height: floor(view.bounds.height))
        guard wanted.width > 0, wanted.height > 0, wanted != display.displaySize else {
            return
        }
        display.requestResolution(CGRect(origin: .zero, size: wanted))
    }

    // MARK: - Mouse

    /// Converts the location of an event into guest display coordinates (origin in the top left corner)
    private func displayPoint(for event: NSEvent) -> CGPoint? {
        guard let display, let renderer, let window = view.window else {
            return nil
        }
        let size = display.displaySize
        guard size.width > 0, size.height > 0, renderer.viewportScale > 0 else {
            return nil
        }

        let bounds = displayView.bounds
        let location = displayView.convert(event.locationInWindow, from: nil)
        // viewportScale is expressed in pixels, mouse locations in points
        let pointsPerDisplayPixel = renderer.viewportScale / window.backingScaleFactor
        let x = (location.x - bounds.midX) / pointsPerDisplayPixel + size.width / 2
        let y = (bounds.midY - location.y) / pointsPerDisplayPixel + size.height / 2
        return CGPoint(x: min(max(x, 0), size.width - 1), y: min(max(y, 0), size.height - 1))
    }

    private func handleMouseMoved(_ event: NSEvent) {
        guard let input else {
            return
        }
        let guestCursor = guestCursor
        displayView.hidesHostCursor = guestCursor != nil

        if input.serverModeCursor {
            input.sendMouseMotion(pressedMouseButtons, relativePoint: CGPoint(x: event.deltaX, y: event.deltaY))
        } else if let point = displayPoint(for: event) {
            input.sendMousePosition(pressedMouseButtons, absolutePoint: point)
            guestCursor?.move(to: point)
        }
    }

    /// Cursor channel of the current display, if the guest exposes one.
    ///
    /// Accessed through key-value coding on purpose: Swift imports both `CSDisplay.cursor` and the
    /// `cursorSource` requirement of `CSRenderSource` under the name `cursor`, and the resulting
    /// ambiguity crashes the Swift 6.4 type checker.
    private var guestCursor: CSCursor? {
        display?.value(forKey: "cursor") as? CSCursor
    }

    private func handleMouseButton(_ button: CSInputButton, pressed: Bool) {
        guard let input else {
            return
        }
        if pressed {
            pressedMouseButtons.insert(button)
        } else {
            pressedMouseButtons.remove(button)
        }
        input.sendMouseButton(button, mask: pressedMouseButtons, pressed: pressed)
    }

    private func handleScroll(_ event: NSEvent) {
        guard let input else {
            return
        }
        // Trackpads report pixel deltas: turn roughly 20 points into one wheel notch
        let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / 20 : event.scrollingDeltaY
        guard dy != 0 else {
            return
        }
        // AppKit reports a positive delta when scrolling up, CocoaSpice expects a negative one
        input.sendMouseScroll(.smooth, buttonMask: pressedMouseButtons, dy: -dy)
    }

    // MARK: - Keyboard

    private func handleFlagsChanged(_ event: NSEvent) {
        // flagsChanged is sent both on press and on release of a modifier key: alternate between the two
        let keyCode = event.keyCode
        if pressedModifierKeyCodes.contains(keyCode) {
            pressedModifierKeyCodes.remove(keyCode)
            sendKey(keyCode, pressed: false)
        } else {
            pressedModifierKeyCodes.insert(keyCode)
            sendKey(keyCode, pressed: true)
        }
    }

    private func sendKey(_ keyCode: UInt16, pressed: Bool) {
        guard let input else {
            return
        }
        if keyCode == Self.pauseKeyCode {
            input.sendPause(pressed ? .press : .release)
            return
        }
        guard var scancode = Self.scancodes[keyCode] else {
            return
        }
        // CocoaSpice expects extended (0xE0 prefixed) scancodes to be flagged with 0x100
        if scancode & 0xFF00 == 0xE000 {
            scancode = 0x100 | (scancode & 0xFF)
        }
        input.send(pressed ? .press : .release, code: Int32(scancode))
    }

    private func releaseAllKeys() {
        input?.releaseKeys()
        pressedModifierKeyCodes.removeAll()
        pressedMouseButtons = []
    }

    /// macOS virtual key code of F15, which is sent to the guest as the Pause key
    private static let pauseKeyCode: UInt16 = 0x71

    /// Maps macOS virtual key codes to PC XT (set 1) scancodes
    private static let scancodes: [UInt16: Int] = [
        0x00: 0x1E, // A
        0x01: 0x1F, // S
        0x02: 0x20, // D
        0x03: 0x21, // F
        0x04: 0x23, // H
        0x05: 0x22, // G
        0x06: 0x2C, // Z
        0x07: 0x2D, // X
        0x08: 0x2E, // C
        0x09: 0x2F, // V
        0x0A: 0x56, // ISO section
        0x0B: 0x30, // B
        0x0C: 0x10, // Q
        0x0D: 0x11, // W
        0x0E: 0x12, // E
        0x0F: 0x13, // R
        0x10: 0x15, // Y
        0x11: 0x14, // T
        0x12: 0x02, // 1
        0x13: 0x03, // 2
        0x14: 0x04, // 3
        0x15: 0x05, // 4
        0x16: 0x07, // 6
        0x17: 0x06, // 5
        0x18: 0x0D, // =
        0x19: 0x0A, // 9
        0x1A: 0x08, // 7
        0x1B: 0x0C, // -
        0x1C: 0x09, // 8
        0x1D: 0x0B, // 0
        0x1E: 0x1B, // ]
        0x1F: 0x18, // O
        0x20: 0x16, // U
        0x21: 0x1A, // [
        0x22: 0x17, // I
        0x23: 0x19, // P
        0x24: 0x1C, // Return
        0x25: 0x26, // L
        0x26: 0x24, // J
        0x27: 0x28, // '
        0x28: 0x25, // K
        0x29: 0x27, // ;
        0x2A: 0x2B, // \
        0x2B: 0x33, // ,
        0x2C: 0x35, // /
        0x2D: 0x31, // N
        0x2E: 0x32, // M
        0x2F: 0x34, // .
        0x30: 0x0F, // Tab
        0x31: 0x39, // Space
        0x32: 0x29, // `
        0x33: 0x0E, // Backspace
        0x35: 0x01, // Escape
        0x36: 0xE05C, // Right Command
        0x37: 0xE05B, // Left Command
        0x38: 0x2A, // Left Shift
        0x39: 0x3A, // Caps Lock
        0x3A: 0x38, // Left Option
        0x3B: 0x1D, // Left Control
        0x3C: 0x36, // Right Shift
        0x3D: 0xE038, // Right Option
        0x3E: 0xE01D, // Right Control
        0x40: 0x68, // F17
        0x41: 0x53, // Keypad .
        0x43: 0x37, // Keypad *
        0x45: 0x4E, // Keypad +
        0x47: 0x45, // Keypad Clear (Num Lock)
        0x48: 0xE030, // Volume Up
        0x49: 0xE02E, // Volume Down
        0x4A: 0xE020, // Mute
        0x4B: 0xE035, // Keypad /
        0x4C: 0xE01C, // Keypad Enter
        0x4E: 0x4A, // Keypad -
        0x4F: 0x69, // F18
        0x50: 0x6A, // F19
        0x51: 0x59, // Keypad =
        0x52: 0x52, // Keypad 0
        0x53: 0x4F, // Keypad 1
        0x54: 0x50, // Keypad 2
        0x55: 0x51, // Keypad 3
        0x56: 0x4B, // Keypad 4
        0x57: 0x4C, // Keypad 5
        0x58: 0x4D, // Keypad 6
        0x59: 0x47, // Keypad 7
        0x5A: 0x6B, // F20
        0x5B: 0x48, // Keypad 8
        0x5C: 0x49, // Keypad 9
        0x5D: 0x7D, // JIS Yen
        0x5E: 0x73, // JIS Underscore
        0x5F: 0x7E, // JIS Keypad ,
        0x60: 0x3F, // F5
        0x61: 0x40, // F6
        0x62: 0x41, // F7
        0x63: 0x3D, // F3
        0x64: 0x42, // F8
        0x65: 0x43, // F9
        0x66: 0x7B, // JIS Eisu
        0x67: 0x57, // F11
        0x68: 0x70, // JIS Kana
        0x69: 0xE037, // F13 (Print Screen)
        0x6A: 0x67, // F16
        0x6B: 0x46, // F14 (Scroll Lock)
        0x6D: 0x44, // F10
        0x6E: 0xE05D, // Contextual Menu
        0x6F: 0x58, // F12
        0x72: 0xE052, // Help (Insert)
        0x73: 0xE047, // Home
        0x74: 0xE049, // Page Up
        0x75: 0xE053, // Forward Delete
        0x76: 0x3E, // F4
        0x77: 0xE04F, // End
        0x78: 0x3C, // F2
        0x79: 0xE051, // Page Down
        0x7A: 0x3B, // F1
        0x7B: 0xE04B, // Left Arrow
        0x7C: 0xE04D, // Right Arrow
        0x7D: 0xE050, // Down Arrow
        0x7E: 0xE048, // Up Arrow
    ]
}

// MARK: - SpiceDisplayViewInputDelegate

extension QemuSpiceViewerViewController: SpiceDisplayViewInputDelegate {
    fileprivate func displayView(_: SpiceDisplayView, didReceive event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            handleMouseButton(.left, pressed: true)
        case .leftMouseUp:
            handleMouseButton(.left, pressed: false)
        case .rightMouseDown:
            handleMouseButton(.right, pressed: true)
        case .rightMouseUp:
            handleMouseButton(.right, pressed: false)
        case .otherMouseDown where event.buttonNumber == 2:
            handleMouseButton(.middle, pressed: true)
        case .otherMouseUp where event.buttonNumber == 2:
            handleMouseButton(.middle, pressed: false)
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            handleMouseMoved(event)
        case .scrollWheel:
            handleScroll(event)
        case .keyDown where !event.isARepeat:
            sendKey(event.keyCode, pressed: true)
        case .keyUp:
            sendKey(event.keyCode, pressed: false)
        case .flagsChanged:
            handleFlagsChanged(event)
        default:
            break
        }
    }
}

// MARK: - CSConnectionDelegate

extension QemuSpiceViewerViewController: CSConnectionDelegate {
    // All callbacks arrive on the SPICE worker thread: hop to the main actor before touching any UI state

    nonisolated func spiceConnected(_: CSConnection) {
        Task { @MainActor in
            self.lastErrorMessage = nil
            self.hasConnected = true
            self.connectionDeadline = nil
        }
    }

    nonisolated func spiceDisconnected(_ connection: CSConnection) {
        Task { @MainActor in
            guard self.connection === connection else {
                return
            }
            self.detachDisplay()
            self.input = nil
            self.displayView.capturesKeyEquivalents = false
            self.connection = nil
            if self.isConnecting {
                // A failed attempt has been torn down (see spiceError): try again rather than closing the viewer
                self.retryConnection()
            } else {
                self.view.window?.close()
            }
        }
    }

    nonisolated func spiceInputAvailable(_: CSConnection, input: CSInput) {
        Task { @MainActor in
            self.input = input
            // ⌘ shortcuts belong to the guest from now on
            self.displayView.capturesKeyEquivalents = true
            // Ask for absolute mouse positioning (client mode), which maps naturally onto a windowed viewer
            input.requestMouseMode(false)
        }
    }

    nonisolated func spiceInputUnavailable(_: CSConnection, input: CSInput) {
        Task { @MainActor in
            if self.input === input {
                self.input = nil
                self.displayView.capturesKeyEquivalents = false
            }
        }
    }

    nonisolated func spiceError(_ connection: CSConnection, code: CSConnectionError, message: String?) {
        Task { @MainActor in
            let text = String(format: NSLocalizedString("QemuSpiceViewerViewController.error", comment: ""), message ?? "\(code.rawValue)")
            self.lastErrorMessage = text
            if self.isConnecting, self.connection === connection {
                // CocoaSpice does not tear the session down after a failed connect: do it here so that
                // spiceDisconnected(_:) fires and schedules the next attempt. Keep showing "Connecting…" meanwhile
                connection.disconnect()
            } else {
                self.showStatus(text)
            }
        }
    }

    nonisolated func spiceDisplayCreated(_: CSConnection, display: CSDisplay) {
        Task { @MainActor in
            self.attach(display)
        }
    }

    nonisolated func spiceDisplayUpdated(_: CSConnection, display: CSDisplay) {
        Task { @MainActor in
            if self.display === display {
                self.displaySizeChanged()
            }
        }
    }

    nonisolated func spiceDisplayDestroyed(_: CSConnection, display: CSDisplay) {
        Task { @MainActor in
            if self.display === display {
                self.detachDisplay()
            }
        }
    }

    nonisolated func spiceAgentConnected(_: CSConnection, supportingFeatures features: CSConnectionAgentFeature) {
        Task { @MainActor in
            self.agentSupportsMonitorsConfig = features.contains(.monitorsConfig)
            self.scheduleResolutionRequest()
        }
    }

    nonisolated func spiceAgentDisconnected(_: CSConnection) {
        Task { @MainActor in
            self.agentSupportsMonitorsConfig = false
        }
    }

    nonisolated func spiceForwardedPortOpened(_: CSConnection, port _: CSPort) {}

    nonisolated func spiceForwardedPortClosed(_: CSConnection, port _: CSPort) {}
}

// MARK: - SpiceDisplayView

private protocol SpiceDisplayViewInputDelegate: AnyObject {
    func displayView(_ view: SpiceDisplayView, didReceive event: NSEvent)
}

/// Metal view that presents the guest framebuffer and forwards every keyboard and mouse event to its delegate
private final class SpiceDisplayView: MTKView {
    weak var inputDelegate: SpiceDisplayViewInputDelegate?

    /// When true the host cursor is hidden over the view, because the guest cursor is drawn by the renderer
    var hidesHostCursor = false {
        didSet {
            if hidesHostCursor != oldValue {
                window?.invalidateCursorRects(for: self)
            }
        }
    }

    private static let blankCursor: NSCursor = {
        let image = NSImage(size: NSSize(width: 1, height: 1), flipped: false) { _ in true }
        return NSCursor(image: image, hotSpot: .zero)
    }()

    private var trackingArea: NSTrackingArea?

    /// When true, Command key combinations are forwarded to the guest instead of triggering menu items
    var capturesKeyEquivalents = false

    override var acceptsFirstResponder: Bool {
        true
    }

    /// Key equivalents (Command combinations such as ⌘Q or ⌘W) are offered to the views before the menu bar
    /// and never reach `keyDown`: claim them here so that the guest receives them
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard capturesKeyEquivalents, window?.firstResponder === self, event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        inputDelegate?.displayView(self, didReceive: event)
        return true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        if hidesHostCursor {
            addCursorRect(bounds, cursor: Self.blankCursor)
        }
    }

    override func mouseDown(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func mouseUp(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func mouseDragged(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func mouseMoved(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func scrollWheel(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func keyDown(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func keyUp(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }

    override func flagsChanged(with event: NSEvent) {
        inputDelegate?.displayView(self, didReceive: event)
    }
}
