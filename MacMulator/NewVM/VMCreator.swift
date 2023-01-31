//
//  VMCreator.swift
//  MacMulator
//
//  Created by Vale on 10/04/22.
//

import Foundation

protocol VMCreator {
    
    func createVM(vm: VirtualMachine, installMedia: String) throws
    
    func isComplete() -> Bool
    
    func setProgress(_ progress: Double)
    
    func getProgress() -> Double
    
    func cancelVMCreation(vm: VirtualMachine)
}
