//
//  MQTTStream.swift
//  Sunapsis
//
//  Created by Ryan Moniz on 2017-11-09.
//

import Foundation

final class MQTTStream: NSObject, StreamDelegate, SocketBackend {
    
    //MARK: Stream Delegate Methods
    
    //MARK: Socket Backend Delegate Methods
    override static func className() -> String {
        return "MQTTStream"
    }
    
    public func connect(to host: String, port: Int32, timeout: UInt = 0) throws {
        
    }
    
    public func close() {
        
    }
    
    func write(from data: Data) throws -> Int {
        return 0
    }
    
    func write(from data: NSData) throws -> Int {
        return 0
    }
    
    func write(from string: String) throws -> Int {
        return 0
    }
    
    func readString() throws -> String? {
        return nil
    }
    
    func read(into data: inout Data) throws -> Int {
        return 0
    }
    
    func read(into data: NSMutableData) throws -> Int {
        return 0
    }
}
