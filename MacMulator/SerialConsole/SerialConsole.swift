//
//  SerialConsole.swift
//  MacMulator
//
//  Created by Vale on 03/11/2026.
//

protocol SerialConsole: AnyObject {
    func attach(_ handler: @escaping (Data) -> Void)
    func detach()
    func send(_ data: Data)
}
