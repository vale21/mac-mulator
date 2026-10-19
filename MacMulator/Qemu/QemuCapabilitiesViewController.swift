//
//  QemuCapabilitiesViewController.swift
//  MacMulator
//
//  Created by Vale on 19/10/2026.
//

import Cocoa

class QemuCapabilitiesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet var qemuVersionLabel: NSTextField!

    @IBOutlet var qemuBinariesLabel: NSTextField!
    @IBOutlet var qemuSystemX86_64Indicator: NSImageView!
    @IBOutlet var qemuSystemI386Indicator: NSImageView!
    @IBOutlet var qemuSystemAarch64Indicator: NSImageView!
    @IBOutlet var qemuSystemArmIndicator: NSImageView!
    @IBOutlet var qemuSystemPpc64Indicator: NSImageView!
    @IBOutlet var qemuSystemPpcIndicator: NSImageView!
    @IBOutlet var qemuSystemRiscv64Indicator: NSImageView!
    @IBOutlet var qemuSystemRiscvIndicator: NSImageView!
    @IBOutlet var qemuSystemM68kIndicator: NSImageView!

    @IBOutlet var otherBinariesLabel: NSTextField!
    @IBOutlet var qemuImgIndicator: NSImageView!
    @IBOutlet var swtpmIndicator: NSImageView!

    @IBOutlet var featuresLabel: NSTextField!
    @IBOutlet var virGLRendererIndicator: NSImageView!
    @IBOutlet var spiceIndicator: NSImageView!
    @IBOutlet var vmNetIndicator: NSImageView!

    @IBOutlet var qemuDisplaysTableHeader: NSTableHeaderView!
    @IBOutlet var qemuDisplaysTableView: NSTableView!

    @IBOutlet var qemuVideoAdaptersTableHeader: NSTableHeaderView!
    @IBOutlet var qemuVideopAdapterTableView: NSTableView!

    @IBOutlet var qemuNetworkAdaptersTableHeader: NSTableHeaderView!
    @IBOutlet var qemuNetworkAdaptersTableView: NSTableView!

    private var displays: [String] = []
    private var videoAdapters: [String] = []
    private var networkAdapters: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        qemuDisplaysTableView.tableColumns.first?.headerCell.stringValue = "QEMU Displays"
        qemuVideopAdapterTableView.tableColumns.first?.headerCell.stringValue = "QEMU Video adapters"
        qemuNetworkAdaptersTableView.tableColumns.first?.headerCell.stringValue = "QEMU Network adapters"
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        Task {
            let capabilities = await QemuCapabilitiesReporter.getInstance(forQemuPath: QemuUtils.getQemuPath())
            updateView(with: capabilities)
        }
    }

    private func updateView(with capabilities: QemuCapabilitiesReporter?) {
        refreshQemuVersion()

        setIndicator(qemuSystemX86_64Indicator, capabilities?.hasx86_64Binary ?? false)
        setIndicator(qemuSystemI386Indicator, capabilities?.hasX86Binary ?? false)
        setIndicator(qemuSystemAarch64Indicator, capabilities?.hasAarch64Binary ?? false)
        setIndicator(qemuSystemArmIndicator, capabilities?.hasArmBinary ?? false)
        setIndicator(qemuSystemPpc64Indicator, capabilities?.hasPowerPC64Binary ?? false)
        setIndicator(qemuSystemPpcIndicator, capabilities?.hasPowerPCBinary ?? false)
        setIndicator(qemuSystemRiscv64Indicator, capabilities?.hasRiscv64Binary ?? false)
        setIndicator(qemuSystemRiscvIndicator, capabilities?.hasRiscvBinary ?? false)
        setIndicator(qemuSystemM68kIndicator, capabilities?.hasM68kBinary ?? false)

        setIndicator(qemuImgIndicator, capabilities?.hasQemuImgBinary ?? false)
        setIndicator(swtpmIndicator, capabilities?.hasSwtpmBinary ?? false)

        setIndicator(virGLRendererIndicator, capabilities?.virGLSupported ?? false)
        setIndicator(spiceIndicator, capabilities?.spiceSupported ?? false)
        setIndicator(vmNetIndicator, capabilities?.vmnetSupported ?? false)

        displays = capabilities?.availableDisplays ?? []
        videoAdapters = capabilities?.availableVideoDevices ?? []
        networkAdapters = capabilities?.availableNetworkDevices ?? []

        qemuDisplaysTableView.reloadData()
        qemuVideopAdapterTableView.reloadData()
        qemuNetworkAdaptersTableView.reloadData()
    }

    private func setIndicator(_ view: NSImageView, _ value: Bool) {
        if value {
            setGreenTick(view)
        } else {
            setRedCross(view)
        }
    }

    private func items(for tableView: NSTableView) -> [String] {
        if tableView == qemuDisplaysTableView {
            return displays
        } else if tableView == qemuVideopAdapterTableView {
            return videoAdapters
        } else if tableView == qemuNetworkAdaptersTableView {
            return networkAdapters
        }
        return []
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        items(for: tableView).count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn,
              let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView
        else {
            return nil
        }
        cell.textField?.stringValue = items(for: tableView)[row]
        return cell
    }

    private func refreshQemuVersion() {
        let qemuPath = QemuUtils.getQemuPath()
        Task {
            let capabilities = await QemuCapabilitiesReporter.getInstance(forQemuPath: qemuPath)
            if let version = capabilities?.qemuVersion, !version.isEmpty {
                qemuVersionLabel.stringValue = String(format: NSLocalizedString("RootViewController.qemuVersion", comment: ""), version)
            } else {
                qemuVersionLabel.stringValue = NSLocalizedString("RootViewController.qemuNotFound", comment: "")
            }
        }
    }

    fileprivate func setGreenTick(_ view: NSImageView) {
        if #available(macOS 11, *) {
            view.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
            view.contentTintColor = NSColor.systemGreen
        } else {
            view.image = NSImage(named: "checkmark.circle.fill")
        }
    }

    fileprivate func setYellowCross(_ view: NSImageView) {
        if #available(macOS 11, *) {
            view.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
            view.contentTintColor = NSColor.systemYellow
        } else {
            view.image = NSImage(named: NSImage.Name("xmark.circle.fill.yellow"))
        }
    }

    fileprivate func setRedCross(_ view: NSImageView) {
        if #available(macOS 11, *) {
            view.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
            view.contentTintColor = NSColor.systemRed
        } else {
            view.image = NSImage(named: "xmark.circle.fill")
        }
    }
}
