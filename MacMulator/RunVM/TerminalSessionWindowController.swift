//
//  TerminalSessionWindowController.swift
//  MacMulator
//
//  Created by Vale on 30/10/2026.
//

import Cocoa
import SwiftTerm

/// A MacMulator window hosting a shell session on a running VM: an SSH connection, or its serial console.
/// The session is rendered by SwiftTerm; closing the window ends it, leaving the VM running.
class TerminalSessionWindowController: NSWindowController, NSWindowDelegate, LocalProcessTerminalViewDelegate {
    enum Kind {
        case ssh
        case serialConsole
    }

    /// Open sessions, kept alive until their window closes
    private static var openSessions: [TerminalSessionWindowController] = []

    private let kind: Kind
    private let virtualMachine: VirtualMachine
    private let terminalView: TerminalView
    /// Set when the terminal is connected to the serial console of an Apple VM rather than to a local process
    private var serialConsole: SerialConsole?
    private var serialConsoleDelegate: SerialConsoleTerminalDelegate?
    private var spinner: NSProgressIndicator?
    private var isClosed = false

    private static let defaultFrame = NSRect(x: 0, y: 0, width: 800, height: 500)

    /// The environment of the process: the usual terminal one, but with every prompt (host key, password) asked in the
    /// terminal. With DISPLAY set (e.g. by XQuartz), ssh would run the X11 ssh-askpass instead, which usually is missing
    private static var environment: [String] {
        Terminal.getEnvironmentVariables(termName: "xterm-256color").filter { !$0.hasPrefix("DISPLAY=") } + ["SSH_ASKPASS_REQUIRE=never"]
    }

    private init(_ kind: Kind, _ virtualMachine: VirtualMachine, _ terminalView: TerminalView) {
        self.kind = kind
        self.virtualMachine = virtualMachine
        self.terminalView = terminalView

        let window = NSWindow(contentRect: terminalView.frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        let titleFormat = kind == .ssh ? NSLocalizedString("TerminalSessionWindowController.sshTitle", comment: "") : NSLocalizedString("TerminalSessionWindowController.serialConsoleTitle", comment: "")
        window.title = String(format: titleFormat, virtualMachine.displayName)
        // The terminal sits in a container of its own: SwiftTerm stacks its subviews as it pleases, so the spinner
        // must not be one of them
        let container = NSView(frame: terminalView.frame)
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminalView)
        NSLayoutConstraint.activate([
            terminalView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            terminalView.topAnchor.constraint(equalTo: container.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        window.contentView = container
        window.minSize = NSSize(width: 400, height: 200)
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.delegate = self
        terminalView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_: Notification) {
        isClosed = true
        hideSpinner()
        (terminalView as? LocalProcessTerminalView)?.terminate()
        serialConsole?.detach()
        TerminalSessionWindowController.openSessions.removeAll { $0 === self }
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source _: LocalProcessTerminalView, newCols _: Int, newRows _: Int) {}

    func setTerminalTitle(source _: LocalProcessTerminalView, title _: String) {}

    func hostCurrentDirectoryUpdate(source _: TerminalView, directory _: String?) {}

    func processTerminated(source _: TerminalView, exitCode _: Int32?) {
        DispatchQueue.main.async {
            // Keep the window open, so that the last output (e.g. an SSH error) can still be read
            self.terminalView.feed(text: "\r\n" + NSLocalizedString("TerminalSessionWindowController.sessionEnded", comment: "") + "\r\n")
        }
    }

    /// Opens a session running `executable` with `args` in a pseudo-terminal, or brings the existing one of the same kind to the front
    static func open(_ kind: Kind, on virtualMachine: VirtualMachine, executable: String, args: [String]) {
        if bringExistingToFront(kind, virtualMachine) {
            return
        }

        let terminalView = LocalProcessTerminalView(frame: defaultFrame)
        let session = TerminalSessionWindowController(kind, virtualMachine, terminalView)
        terminalView.processDelegate = session
        session.show()
        terminalView.startProcess(executable: executable, args: args, environment: environment)
    }

    /// Opens the window of a session whose process is not known yet, e.g. because it needs the IP address of the guest.
    /// A spinner is shown in it until `start` (or `cancel`) is called
    static func openPending(_ kind: Kind, on virtualMachine: VirtualMachine) -> TerminalSessionWindowController {
        let terminalView = LocalProcessTerminalView(frame: defaultFrame)
        let session = TerminalSessionWindowController(kind, virtualMachine, terminalView)
        terminalView.processDelegate = session
        session.show()
        session.showSpinner()
        return session
    }

    /// Opens a session on the serial console of an Apple VM, or brings the existing one to the front
    static func open(_ serialConsole: SerialConsole, on virtualMachine: VirtualMachine) {
        if bringExistingToFront(.serialConsole, virtualMachine) {
            return
        }

        let terminalView = TerminalView(frame: defaultFrame)
        let session = TerminalSessionWindowController(.serialConsole, virtualMachine, terminalView)
        let delegate = SerialConsoleTerminalDelegate(serialConsole)
        terminalView.terminalDelegate = delegate
        session.serialConsole = serialConsole
        session.serialConsoleDelegate = delegate
        session.show()
        // The terminal answers the queries it finds in the output (e.g. the cursor position asked by agetty). Those in
        // the output printed before the window was opened were answered already, and the guest would only echo a late
        // answer at its login prompt: leave them out of the output shown again
        var isReplay = true
        serialConsole.attach { [weak terminalView] data in
            terminalView?.feed(byteArray: ArraySlice(isReplay ? removingTerminalQueries(from: data) : data))
        }
        isReplay = false
    }

    /// Brings the session of this kind on the VM to the front. Returns false if there is none
    static func bringExistingToFront(_ kind: Kind, _ virtualMachine: VirtualMachine) -> Bool {
        guard let existing = openSessions.first(where: { $0.kind == kind && $0.virtualMachine == virtualMachine }) else { return false }
        existing.window?.makeKeyAndOrderFront(nil)
        return true
    }

    /// Closes every session on the VM, e.g. because it has stopped
    static func closeSessions(on virtualMachine: VirtualMachine) {
        for session in openSessions.filter({ $0.virtualMachine == virtualMachine }) {
            session.window?.close()
        }
    }

    /// Starts the process of a session opened with `openPending`, and lets the user type in it
    func start(executable: String, args: [String], banner: String? = nil) {
        guard !isClosed, let terminalView = terminalView as? LocalProcessTerminalView else { return }

        hideSpinner()
        if let banner {
            terminalView.feed(text: banner + "\r\n")
        }
        terminalView.startProcess(executable: executable, args: args, environment: TerminalSessionWindowController.environment)
        window?.makeFirstResponder(terminalView)
    }

    /// Closes a session opened with `openPending` whose process could not be determined
    func cancel() {
        window?.close()
    }

    private func show() {
        TerminalSessionWindowController.openSessions.append(self)
        showWindow(nil)
        window?.makeFirstResponder(terminalView)
    }

    private func showSpinner() {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.isIndeterminate = true
        spinner.controlSize = .regular
        spinner.translatesAutoresizingMaskIntoConstraints = false
        guard let container = window?.contentView else { return }

        container.addSubview(spinner, positioned: .above, relativeTo: terminalView)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        spinner.startAnimation(nil)
        self.spinner = spinner
    }

    private func hideSpinner() {
        spinner?.stopAnimation(nil)
        spinner?.removeFromSuperview()
        spinner = nil
    }
}

/// Sends what is typed in a terminal to the serial console of an Apple VM
private class SerialConsoleTerminalDelegate: TerminalViewDelegate {
    private let serialConsole: SerialConsole
    init(_ serialConsole: SerialConsole) {
        self.serialConsole = serialConsole
    }

    func send(source _: TerminalView, data: ArraySlice<UInt8>) {
        serialConsole.send(Data(data))
    }

    // A serial line has no notion of window size, title or current directory
    func sizeChanged(source _: TerminalView, newCols _: Int, newRows _: Int) {}

    func setTerminalTitle(source _: TerminalView, title _: String) {}

    func hostCurrentDirectoryUpdate(source _: TerminalView, directory _: String?) {}

    func scrolled(source _: TerminalView, position _: Double) {}

    func rangeChanged(source _: TerminalView, startY _: Int, endY _: Int) {}
}

/// The output without the escape sequences that ask the terminal to answer: device status reports such as the cursor
/// position (ESC [ 6 n) and device attributes (ESC [ c, ESC [ > c)
private func removingTerminalQueries(from data: Data) -> Data {
    let bytes = [UInt8](data)
    var result: [UInt8] = []
    result.reserveCapacity(bytes.count)

    var index = 0
    while index < bytes.count {
        if bytes[index] == 0x1B, index + 1 < bytes.count, bytes[index + 1] == UInt8(ascii: "[") {
            // CSI: optional private marker, parameters, then the final byte
            var end = index + 2
            if end < bytes.count, [UInt8(ascii: "?"), UInt8(ascii: ">"), UInt8(ascii: "=")].contains(bytes[end]) {
                end += 1
            }
            while end < bytes.count, (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains(bytes[end]) || bytes[end] == UInt8(ascii: ";") {
                end += 1
            }
            if end < bytes.count, bytes[end] == UInt8(ascii: "n") || bytes[end] == UInt8(ascii: "c") {
                index = end + 1
                continue
            }
        }
        result.append(bytes[index])
        index += 1
    }
    return Data(result)
}
