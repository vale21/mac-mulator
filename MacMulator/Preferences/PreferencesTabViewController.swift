//
//  PreferencesTabViewController.swift
//  MacMulator
//
//  Created by Vale on 25/11/26.
//

import Cocoa

struct PreferencesRequest {
    let tabIdentifier: String?
    weak var networkSelectionTarget: VmnetNetworkSelector?
}

class PreferencesTabViewController: NSTabViewController {
    static let GENERAL_TAB = "general"
    static let NETWORKS_TAB = "networks"

    var rootController: RootViewController?
    private var observedWindow: NSWindow?

    func setRootController(_ rootController: RootViewController) {
        self.rootController = rootController
        generalPreferences()?.setRootController(rootController)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        canPropagateSelectedChildViewControllerTitle = false

        #if APPSTORE
            // The Qemu and workspace folders are fixed in the App Store version
            removeTab(PreferencesTabViewController.GENERAL_TAB)
        #endif
        if !Utils.isVmnetSupportedOnHost() {
            removeTab(PreferencesTabViewController.NETWORKS_TAB)
        }

        for item in tabViewItems {
            item.label = NSLocalizedString("PreferencesTabViewController." + (item.identifier as? String ?? ""), comment: "")
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.title = NSLocalizedString("PreferencesViewController.windowTitle", comment: "")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window, window !== observedWindow {
            if let observedWindow {
                NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: observedWindow)
            }
            NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: window)
            observedWindow = window
        }
    }

    static func hasTabs() -> Bool {
        #if APPSTORE
            Utils.isVmnetSupportedOnHost()
        #else
            true
        #endif
    }

    func apply(_ request: PreferencesRequest?) {
        if let identifier = request?.tabIdentifier, let index = tabViewItems.firstIndex(where: { $0.identifier as? String == identifier }) {
            selectedTabViewItemIndex = index
        }
        networksPreferences()?.networkSelectionTarget = request?.networkSelectionTarget
    }

    @objc private func windowWillClose(_: Notification) {
        generalPreferences()?.preferencesWindowClosed()
    }

    private func removeTab(_ identifier: String) {
        if let item = tabViewItems.first(where: { $0.identifier as? String == identifier }) {
            removeTabViewItem(item)
        }
    }

    private func generalPreferences() -> PreferencesViewController? {
        tabViewItems.compactMap { $0.viewController as? PreferencesViewController }.first
    }

    private func networksPreferences() -> ManageVmnetNetworksViewController? {
        tabViewItems.compactMap { $0.viewController as? ManageVmnetNetworksViewController }.first
    }
}
