//
//  VirtualMachineRunner.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation

protocol VirtualmachineRunner {
    
    func getVirtualMachine() -> VirtualMachine;
    
    func getListenPort() -> Int32;
    
    func isRunning() -> Bool;
    
    func runVM(uponCompletion callback: @escaping (Int32, VirtualMachine) -> Void);
    
    func kill();
    
    func getStandardError() -> String;
    
    func getStandardOutput() -> String;
    
    func getConsoleOutput() -> String;
}
