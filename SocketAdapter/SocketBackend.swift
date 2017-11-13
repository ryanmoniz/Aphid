//
//  SocketBackend.swift
//
//  Created by Ryan Moniz on 2017-05-24.
//  Copyright © IBM Corp. 2017. All rights reserved.
//

import Foundation

public protocol SocketBackend: ConnectionWriter, ConnectionReader {
    //MARK: sharedInstance
    static func className() -> String
    
    //MARK: Properties
    
    //MARK: Lifecycle
    init()
    func connect(to host: String, port: Int32, timeout: UInt) throws
    func close()
}

public protocol ConnectionWriter {
    ///
    /// Writes data from Data object.
    ///
    /// - Parameter data: Data object containing the data to be written.
    ///
    @discardableResult func write(from data: Data) throws -> Int
    
    ///
    /// Writes data from NSData object.
    ///
    /// - Parameter data: NSData object containing the data to be written.
    ///
    @discardableResult func write(from data: NSData) throws -> Int
    
    ///
    /// Writes a string
    ///
    /// - Parameter string: String data to be written.
    ///
    @discardableResult func write(from string: String) throws -> Int
}

///
/// Socket reader protocol
///
public protocol ConnectionReader {
    
    ///
    /// Reads a string.
    ///
    /// - Returns: Optional String
    ///
    func readString() throws -> String?
    
    ///
    /// Reads all available data into an Data object.
    ///
    /// - Parameter data: Data object to contain read data.
    ///
    /// - Returns: Integer representing the number of bytes read.
    ///
    func read(into data: inout Data) throws -> Int
    
    ///
    /// Reads all available data into an NSMutableData object.
    ///
    /// - Parameter data: NSMutableData object to contain read data.
    ///
    /// - Returns: Integer representing the number of bytes read.
    ///
    func read(into data: NSMutableData) throws -> Int
}

