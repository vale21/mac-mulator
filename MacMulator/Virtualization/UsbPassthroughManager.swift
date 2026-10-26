//
//  UsbPassthroughManager.swift
//  MacMulator
//

#if arch(arm64)
    import AccessoryAccess
    import Foundation
    import IOKit

    struct UsbPassthroughCandidate {
        let registryID: UInt64
        let vendorID: UInt16
        let productID: UInt16
        let name: String

        var key: String { String(format: "%04X:%04X", vendorID, productID) }
    }

    @available(macOS 27.0, *)
    final class UsbPassthroughManager: NSObject, AAUSBAccessoryListener, @unchecked Sendable {
        static let shared = UsbPassthroughManager()
        static let didChangeNotification = Notification.Name("UsbPassthroughManagerDidChange")
        static let didConnectNotification = Notification.Name("UsbPassthroughManagerDidConnect")
        static let didRemoveNotification = Notification.Name("UsbPassthroughManagerDidRemove")

        private let lock = NSLock()
        private var accessories: [UInt64: AAUSBAccessory] = [:]
        private var registered = false
        private var registrationFailed = false
        private var ready = false
        private var pendingCompletions: [() -> Void] = []
        private(set) var lastError: String?

        func start(retryAfterFailure: Bool = false, completion: (() -> Void)? = nil) {
            lock.lock()
            if ready {
                lock.unlock()
                completion?()
                return
            }
            if let completion {
                pendingCompletions.append(completion)
            }
            if registered {
                lock.unlock()
                return
            }
            if registrationFailed && !retryAfterFailure {
                lock.unlock()
                return
            }
            registrationFailed = false
            registered = true
            lock.unlock()

            AAUSBAccessoryManager.shared.registerListener(self, matchingCriteria: []) { [weak self] connected, error in
                if let error {
                    NSLog("USB accessory listener registration failed: %@", String(describing: error))
                    self?.lock.lock()
                    self?.registered = false
                    self?.registrationFailed = true
                    self?.lastError = "\(error.localizedDescription) [\((error as NSError).domain) \((error as NSError).code)]"
                    self?.lock.unlock()
                    self?.notifyChange()
                    return
                }
                self?.lock.lock()
                self?.lastError = nil
                for accessory in connected {
                    self?.accessories[accessory.registryID] = accessory
                }
                self?.ready = true
                let completions = self?.pendingCompletions ?? []
                self?.pendingCompletions = []
                self?.lock.unlock()
                completions.forEach { $0() }
                self?.notifyChange()
            }
        }

        func accessory(withRegistryID registryID: UInt64) -> AAUSBAccessory? {
            lock.lock()
            defer { lock.unlock() }
            return accessories[registryID]
        }

        func candidates() -> [UsbPassthroughCandidate] {
            lock.lock()
            let current = Array(accessories.values)
            lock.unlock()

            return current.map { accessory in
                let (vendorID, productID) = Self.ids(of: accessory)
                return UsbPassthroughCandidate(
                    registryID: accessory.registryID,
                    vendorID: vendorID,
                    productID: productID,
                    name: Self.displayName(of: accessory, vendorID: vendorID, productID: productID)
                )
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        func usbAccessoryDidConnect(_ usbAccessory: AAUSBAccessory) {
            lock.lock()
            accessories[usbAccessory.registryID] = usbAccessory
            lock.unlock()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.didConnectNotification, object: nil)
            }
            notifyChange()
        }

        func usbAccessoryDidDisconnect(_ usbAccessory: AAUSBAccessory) {
            lock.lock()
            accessories.removeValue(forKey: usbAccessory.registryID)
            lock.unlock()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.didRemoveNotification, object: nil, userInfo: ["registryID": usbAccessory.registryID])
            }
            notifyChange()
        }

        private func notifyChange() {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
            }
        }

        // idVendor and idProduct sit at offsets 8 and 10 of the USB device descriptor (little endian)
        private static func ids(of accessory: AAUSBAccessory) -> (UInt16, UInt16) {
            let data = accessory.deviceDescriptorData
            guard data.count >= 12 else { return (0, 0) }
            let bytes = [UInt8](data)
            return (UInt16(bytes[8]) | UInt16(bytes[9]) << 8, UInt16(bytes[10]) | UInt16(bytes[11]) << 8)
        }

        private static func displayName(of accessory: AAUSBAccessory, vendorID: UInt16, productID: UInt16) -> String {
            let ids = String(format: "%04X:%04X", vendorID, productID)
            let entry = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(accessory.registryID))
            guard entry != 0 else { return ids }
            defer { IOObjectRelease(entry) }

            if let product = IORegistryEntryCreateCFProperty(entry, "USB Product Name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String, !product.isEmpty {
                return product
            }
            return ids
        }
    }
#endif
