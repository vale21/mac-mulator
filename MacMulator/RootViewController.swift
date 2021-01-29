//
//  ViewController.swift
//  QManage
//
//  Created by Vale on 26/01/21.
//

import Cocoa

class RootViewController: NSSplitViewController {

    struct Drive: Codable {
        var name:String
        var format:String
        var mediaType:String
    }
    
    struct VM: Codable {
        var displayName:String
        var memory:Int
        var displayResolution:String
        var bootArg: String
        var drives: [Drive]
    }
    
    private let libraryPath = "/Volumes/valeMac\\ SSD/Parallels";
    private let qemuPath = "/opt/local/qemu/qemu-system-ppc";
        
    var listController: VirtualMachinesListViewController?;
    var vmController: VirtualMachineViewController?;
    
    override func viewDidLoad() {
        super.viewDidLoad();
            
        let children = self.children;
        
        listController = children[0] as? VirtualMachinesListViewController;
        if let listController = self.listController {
            listController.setRootController(self);
        }
        
        vmController = children[1] as? VirtualMachineViewController;
        if let vmController = self.vmController {
            vmController.setRootController(self);
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func getLibraryPath() -> String {
        return libraryPath;
    }
    
    func getQemuPath() -> String {
        return qemuPath;
    }
    
    func setCurrentVirtualMachine(_ currentVm: VirtualMachine) {
        if let vmController = self.vmController {
            vmController.setVirtualMachine(virtualmachine: currentVm);
        }
    }
    
    func addVirtualMachineFromFile(_ fileName: String) {
                
        let fileManager = FileManager.default;
        do {
            let xml = fileManager.contents(atPath: (fileName + "/Info.plist"));
            let preferences = try PropertyListDecoder().decode(VM.self, from: xml!);
            
            let virtualMachine: VirtualMachine = createVM(preferences);
            
            listController?.addVirtualMachine(virtualMachine);
            self.setCurrentVirtualMachine(virtualMachine);
            
        } catch {
            print("ERROR while reading Info.plist");
        }
    }
    
    private func createVM(_ vm: VM) -> VirtualMachine {
        let virtualMachine = VirtualMachine(displayName: vm.displayName, memory: Int32(vm.memory), displayResolution: vm.displayResolution, bootArg: vm.bootArg);
        for drive: Drive in vm.drives {
            let virtualDrive  = VirtualDrive(name: drive.name, format: drive.format, mediaType: drive.mediaType);
            virtualMachine.addVirtualDrive(drive: virtualDrive);
        }
        
        return virtualMachine;
    }
}

