//
//  UtilsTest.swift
//  MacMulatorTests
//
//  Created by Vale on 10/08/21.
//

@testable import MacMulator
import XCTest

class UtilsTest: XCTestCase {
    var vm: VirtualMachine?

    override func setUpWithError() throws {
        vm = VirtualMachineFactory.makeVirtualMachine()
    }

    override func tearDownWithError() throws {
        vm = nil
    }

    func testFirstElementWithNoEfi() throws {
        let drive = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive)

        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(0, Utils.computeDrivesTableIndex(vm, 0))
    }

    func testIntermediateElementWithNoEfi() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-1", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-2", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)

        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 1))
    }

    func testLastElementWithNoEfi() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-1", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-2", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)

        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 2))
    }

    func testFirstElementWithEfiAtTheBeginning() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "efi-0", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-1", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)

        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 0))
    }

    func testIntermediateElementWithEfiAtTheBeginning() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "efi-0", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-1", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-2", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)
        let drive4 = VirtualMachineFactory.makeDrive(name: "disk-3", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive4)

        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 1))
    }

    func testLastElementWithEfiAtTheBeginning() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "efi-0", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-1", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-2", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)

        XCTAssertEqual(2, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 1))
    }

    func testFirstElementWithEfiInTheMiddle() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "efi-1", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-2", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)

        XCTAssertEqual(2, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(0, Utils.computeDrivesTableIndex(vm, 0))
    }

    func testIntermediateElementWithEfiInTheMiddle_Before() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-1", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "efi-2", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive3)
        let drive4 = VirtualMachineFactory.makeDrive(name: "disk-3", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive4)

        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 1))
    }

    func testIntermediateElementWithEfiInTheMiddle_After() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "efi-1", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-2", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)
        let drive4 = VirtualMachineFactory.makeDrive(name: "disk-3", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive4)

        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 1))
    }

    func testLastElementWithEfiInTheMiddle() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "efi-1", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-2", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 1))
    }

    func testFirstElementWithEfiAtTheEnd() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "efi-1", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive2)

        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(0, Utils.computeDrivesTableIndex(vm, 0))
    }

    func testIntermediateElementWithEfiAtTheEnd() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-1", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-2", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)
        let drive4 = VirtualMachineFactory.makeDrive(name: "efi-3", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive4)

        XCTAssertEqual(3, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 1))
    }

    func testLastElementWithEfiAtTheEnd() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-1", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "efi-2", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive3)

        XCTAssertEqual(2, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 1))
    }

    func testElementBeforeMultipleEfis() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "efi-1", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "efi-2", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive3)

        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(0, Utils.computeDrivesTableIndex(vm, 0))
    }

    func testElementBetweenMultipleEfis() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "efi-0", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-1", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "efi-2", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive3)

        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(1, Utils.computeDrivesTableIndex(vm, 0))
    }

    func testElementAfterMultipleEfis() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "efi-0", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "efi-1", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-2", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)

        XCTAssertEqual(1, Utils.computeDrivesTableSize(vm))
        XCTAssertEqual(2, Utils.computeDrivesTableIndex(vm, 0))
    }

    func testDriveIndexWithOneDrive() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)

        XCTAssertEqual(1, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK))
    }

    func testDriveIndexWithManyDrives() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-1", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-2", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)

        XCTAssertEqual(3, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK))
    }

    func testDriveIndexWithManyDrivesShuffled() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-2", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-1", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)

        XCTAssertEqual(3, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK))
    }

    func testDriveIndexWithHolesInSequence() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-3", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "disk-5", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive3)

        XCTAssertEqual(6, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK))
    }

    func testDriveIndexWithOneDriveAndOneCD() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "cdrom-0", mediaType: QemuConstants.MEDIATYPE_CDROM)
        vm?.drives.append(drive2)

        XCTAssertEqual(1, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK))
    }

    func testDriveIndexWithOneDriveOneCDAndOneEfi() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "cdrom-0", mediaType: QemuConstants.MEDIATYPE_CDROM)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "efi-0", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive3)

        XCTAssertEqual(1, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK))
    }

    func testDriveIndexWithOneDriveOneCDOneEfiAndOneOpencore() throws {
        let drive1 = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        vm?.drives.append(drive1)
        let drive2 = VirtualMachineFactory.makeDrive(name: "cdrom-0", mediaType: QemuConstants.MEDIATYPE_CDROM)
        vm?.drives.append(drive2)
        let drive3 = VirtualMachineFactory.makeDrive(name: "efi-0", mediaType: QemuConstants.MEDIATYPE_EFI)
        vm?.drives.append(drive3)
        let drive4 = VirtualMachineFactory.makeDrive(name: "opencore-0", mediaType: QemuConstants.MEDIATYPE_OPENCORE)
        vm?.drives.append(drive4)

        XCTAssertEqual(1, Utils.computeNextDriveIndex(vm, QemuConstants.MEDIATYPE_DISK))
    }

    func testMainDriveIsTheBootDriveAmongManyDrives() throws {
        let efi = VirtualMachineFactory.makeDrive(name: "efi-0", mediaType: QemuConstants.MEDIATYPE_EFI)
        let cdrom = VirtualMachineFactory.makeDrive(name: "cdrom-0", mediaType: QemuConstants.MEDIATYPE_CDROM)
        let disk = VirtualMachineFactory.makeDrive(name: "disk-0", mediaType: QemuConstants.MEDIATYPE_DISK)
        let bootDisk = VirtualMachineFactory.makeDrive(name: "nvme-0", mediaType: QemuConstants.MEDIATYPE_NVME)
        bootDisk.isBootDrive = true
        cdrom.isBootDrive = true

        XCTAssertTrue(Utils.findMainDrive([efi, cdrom, disk, bootDisk]) === bootDisk)
    }
}
