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
}
