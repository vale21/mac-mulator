//
//  QemuUtilsTest.swift
//  MacMulatorTests
//
//  Created by Vale on 10/08/21.
//

import XCTest
@testable import MacMulator

class UtilsTest: XCTestCase {
    
    var vm: VirtualMachine?;
    
    override func setUpWithError() throws {
        vm = VirtualMachine(os: QemuConstants.OS_MAC, subtype: QemuConstants.SUB_MAC_BIG_SUR, architecture: QemuConstants.ARCH_ARM64, path: "", displayName: "", description: "", memory: 1, cpus: 1, displayResolution: "", qemuBootloader: false);
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSimpleCase() throws {
        let drive = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive);
        XCTAssertEqual(0, Utils.computeDrivesTableIndex(vm, 0));
    }
    
    func testIntermediateElementWithNoEfi() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 1));
    }

    func testLastElementWithNoEfi() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 2));
    }
}
