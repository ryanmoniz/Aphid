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
        
        try socket!.connect(to: config.host, port: config.port)
    }
    
    public func close() {
        if let _socket = socket {
            _socket.close()
        }
    }
}
