//
//  ImportExportHerlper.swift
//  MacMulator
//
//  Created by Vale on 27/11/22.
//

import Foundation

class ImportExportHerlper {
    
    static func exportVmToParallels(vm: VirtualMachine, destinationPath: String) {
        do {
            let parallelsVMPath = destinationPath + "/" + vm.displayName + ".macvm"
            try FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "parallels_template", ofType: nil)!, toPath: parallelsVMPath);
            try FileManager.default.copyItem(atPath: vm.path + "/auxiliary-storage-0", toPath: parallelsVMPath + "/aux.bin");
            try FileManager.default.copyItem(atPath: vm.path + "/disk-0.qvd", toPath: parallelsVMPath + "/disk0.img");
            try FileManager.default.copyItem(atPath: vm.path + "/hardware-model-0", toPath: parallelsVMPath + "/machw.bin");
            try FileManager.default.copyItem(atPath: vm.path + "/machine-identifier-0", toPath: parallelsVMPath + "/macid.bin");
        } catch {
           
        }
    }
}
