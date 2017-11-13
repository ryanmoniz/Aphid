//
//  SocketLayer.swift
//  Sunapsis
//
//  Created by Ryan Moniz on 2017-11-09.
//

import Foundation
import Socket

final class SocketLayer: SocketBackend {
    internal var socket: Socket?

    //MARK: Socket Backend Delegate Methods
    static func className() -> String {
        return "SocketLayer"
    }
    
    public func connect(to host: String, port: Int32, timeout: UInt = 0) throws {
        if socket == nil {
            socket = try Socket.create(family: .inet6, type: .stream, proto: .tcp)
        }
        try socket!.setBlocking(mode: false)
        do {
            try socket!.connect(to: host, port: port)
        } catch _ {
            print ("Error")
        }
        
    }
    
    public func close() {
        if let _socket = socket {
            _socket.close()
        }
    }
    
    func write(from data: Data) throws -> Int {
        if let _socket = socket {
           try _socket.write(from: data)
        }
        return 0
    }
    
    func write(from data: NSData) throws -> Int {
        if let _socket = socket {
            try _socket.write(from: data)
        }
        return 0
    }
    
    func write(from string: String) throws -> Int {
        if let _socket = socket {
            try _socket.write(from: string)
        }
        return 0
    }
    
    func readString() throws -> String? {
        if let _socket = socket {
            return try _socket.readString()
        }
        return nil
    }
    
    func read(into data: inout Data) throws -> Int {
        if let _socket = socket {
            return try _socket.read(into: &data)
        }
        return 0
    }
    
    func read(into data: NSMutableData) throws -> Int {
        if let _socket = socket {
            return try _socket.read(into: data)
        }
        
        return 0
    }
    
}
