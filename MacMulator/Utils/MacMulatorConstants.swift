//
//  MacMulatorConstants.swift
//  MacMulator
//
//  Created by Vale on 23/02/21.
//

import Foundation

class MacMulatorConstants {
    
    static let VM_EXTENSION = "qvm";
    static let DISK_EXTENSION = "qvd";
    static let EFI_EXTENSION = "fd";
    static let IMG_EXTENSION = "img";
    static let INFO_PLIST = "Info.plist";
    
    static let NEW_VM_SEGUE = "newVMSegue";
    static let EDIT_VM_SEGUE = "editVMSegue";
    static let NEW_DISK_SEGUE = "newDiskSegue";
    static let EDIT_DISK_SEGUE = "editDiskSegue";
    static let CREATE_DISK_FILE_SEGUE = "createDiskFileSegue";
    static let CREATE_VM_FILE_SEGUE = "createVmFileSegue";
    static let SHOW_DRIVE_INFO_SEGUE = "showDriveInfoSegue";
    static let PREFERENCES_SEGUE = "preferencesSegue";
    static let SHOW_CONSOLE_SEGUE = "showConsoleSegue";
    
    static let PREFERENCE_KEY_SAVED_VMS = "savedVMs";
    static let PREFERENCE_KEY_VMS_FOLDER_PATH = "vmsFolderPath";
    static let PREFERENCE_KEY_QEMU_PATH = "qemuPath";
    static let PREFERENCE_KEY_LIVE_PREVIEW_RATE = "livePreviewRate";
    static let PREFERENCE_KEY_LIVE_PREVIEW_ENABLED = "livePreviewEnabled";

}
