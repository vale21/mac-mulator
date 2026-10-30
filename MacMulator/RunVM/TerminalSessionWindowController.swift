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
    private var serialConsole: VirtualizationFrameworkSerialConsole?
    private var serialConsoleDelegate: SerialConsoleTerminalDelegate?

    /// Opens a session running `executable` with `args` in a pseudo-terminal, or brings the existing one of the same kind to the front
    static func open(_ kind: Kind, on virtualMachine: VirtualMachine, executable: String, args: [String]) {
        if bringExistingToFront(kind, virtualMachine) {
            return
        }

        let terminalView = LocalProcessTerminalView(frame: defaultFrame)
        let session = TerminalSessionWindowController(kind, virtualMachine, terminalView)
        terminalView.processDelegate = session
        session.show()
        terminalView.startProcess(executable: executable, args: args)
    }

    /// Opens a session on the serial console of an Apple VM, or brings the existing one to the front
    static func open(_ serialConsole: VirtualizationFrameworkSerialConsole, on virtualMachine: VirtualMachine) {
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
        serialConsole.attach { [weak terminalView] data in
            terminalView?.feed(byteArray: ArraySlice(data))
        }
    }

    private static let defaultFrame = NSRect(x: 0, y: 0, width: 800, height: 500)

    private static func bringExistingToFront(_ kind: Kind, _ virtualMachine: VirtualMachine) -> Bool {
        guard let existing = openSessions.first(where: { $0.kind == kind && $0.virtualMachine == virtualMachine }) else { return false }
        existing.window?.makeKeyAndOrderFront(nil)
        return true
    }

    private init(_ kind: Kind, _ virtualMachine: VirtualMachine, _ terminalView: TerminalView) {
        self.kind = kind
        self.virtualMachine = virtualMachine
        self.terminalView = terminalView

        let window = NSWindow(contentRect: terminalView.frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        let titleFormat = kind == .ssh ? NSLocalizedString("TerminalSessionWindowController.sshTitle", comment: "") : NSLocalizedString("TerminalSessionWindowController.serialConsoleTitle", comment: "")
        window.title = String(format: titleFormat, virtualMachine.displayName)
        window.contentView = terminalView
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

    private func show() {
        TerminalSessionWindowController.openSessions.append(self)
        showWindow(nil)
        window?.makeFirstResponder(terminalView)
    }

    func windowWillClose(_: Notification) {
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
}

/// Sends what is typed in a terminal to the serial console of an Apple VM
private class SerialConsoleTerminalDelegate: TerminalViewDelegate {
    private let serialConsole: VirtualizationFrameworkSerialConsole

    init(_ serialConsole: VirtualizationFrameworkSerialConsole) {
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
