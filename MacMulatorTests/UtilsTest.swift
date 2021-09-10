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

    func testFirstElementWithNoEfi() throws {
        let drive = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive);
        
        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(0, Utils.computeDrivesTableIndex(vm, 0));
    }
    
    func testIntermediateElementWithNoEfi() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 1));
    }

    func testLastElementWithNoEfi() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 2));
    }
    
    func testFirstElementWithEfiAtTheBeginning() throws {
        let drive1 = VirtualDrive(path: "", name: "efi-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        
        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 0));
    }

    func testIntermediateElementWithEfiAtTheBeginning() throws {
        let drive1 = VirtualDrive(path: "", name: "efi-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        let drive4 = VirtualDrive(path: "", name: "disk-3", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive4);
        
        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 1));
    }

    func testLastElementWithEfiAtTheBeginning() throws {
        let drive1 = VirtualDrive(path: "", name: "efi-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(2, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 1));
    }
    
    func testFirstElementWithEfiInTheMiddle() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "efi-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(2, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(0, Utils.computeDrivesTableIndex(vm, 0));
    }

    func testIntermediateElementWithEfiInTheMiddle_Before() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "efi-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive3);
        let drive4 = VirtualDrive(path: "", name: "disk-3", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive4);
        
        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 1));
    }
    
    func testIntermediateElementWithEfiInTheMiddle_After() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "efi-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        let drive4 = VirtualDrive(path: "", name: "disk-3", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive4);
        
        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 1));
    }
    
    func testLastElementWithEfiInTheMiddle() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "efi-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 1));
    }
    
    func testFirstElementWithEfiAtTheEnd() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "efi-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive2);
        
        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(0, Utils.computeDrivesTableIndex(vm, 0));
    }

    func testIntermediateElementWithEfiAtTheEnd() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        let drive4 = VirtualDrive(path: "", name: "efi-3", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive4);
        
        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 1));
    }

    func testLastElementWithEfiAtTheEnd() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "efi-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(2, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 1));
    }
    
    func testElementBeforeMultipleEfis() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "efi-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "efi-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(0, Utils.computeDrivesTableIndex(vm, 0));
    }
    
    func testElementBetweenMultipleEfis() throws {
        let drive1 = VirtualDrive(path: "", name: "efi-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "efi-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 0));
    }
    
    func testElementAfterMultipleEfis() throws {
        let drive1 = VirtualDrive(path: "", name: "efi-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "efi-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_EFI, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm));
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 0));
    }
    
    func testDriveIndexWithOneDrive() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        
        XCTAssertEqual(1, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK));
    }
    
    func testDriveIndexWithManyDrives() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(3, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK));
    }
    
    func testDriveIndexWithManyDrivesShuffled() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-2", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-1", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(3, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK));
    }
    
    func testDriveIndexWithHolesInSequence() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-3", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "disk-5", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(6, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK));
    }
    
    func testDriveIndexWithOneDriveAndOneCD() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "cdrom-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_CDROM, size: 0);
        vm?.drives.append(drive2);
        
        XCTAssertEqual(1, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK));
    }
    
    func testDriveIndexWithOneDriveOneCDAndOneEfi() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "cdrom-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_CDROM, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "efi-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_CDROM, size: 0);
        vm?.drives.append(drive3);
        
        XCTAssertEqual(1, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK));
    }
    
    func testDriveIndexWithOneDriveOneCDOneEfiAndOneOpencore() throws {
        let drive1 = VirtualDrive(path: "", name: "disk-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_DISK, size: 0);
        vm?.drives.append(drive1);
        let drive2 = VirtualDrive(path: "", name: "cdrom-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_CDROM, size: 0);
        vm?.drives.append(drive2);
        let drive3 = VirtualDrive(path: "", name: "efi-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_CDROM, size: 0);
        vm?.drives.append(drive3);
        let drive4 = VirtualDrive(path: "", name: "opencore-0", format: QemuConstants.FORMAT_RAW, mediaType: QemuConstants.MEDIATYPE_OPENCORE, size: 0);
        vm?.drives.append(drive4);
        
        XCTAssertEqual(1, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK));
    }
}
