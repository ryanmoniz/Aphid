/**
 Copyright IBM Corporation 2017

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import Dispatch

import Socket
import SSLService


public typealias Byte = UInt8

open class Sunapsis {

    public var delegate: MQTTDelegate?
    
    internal var socket: SocketBackend?

    internal var buffer: Data

    internal var keepAliveTimer: DispatchSourceTimer? = nil

    internal var bound = 2

    internal let readQueue: DispatchQueue
    internal let writeQueue: DispatchQueue

    public init(clientId: String, cleanSess: Bool = true, username: String? = nil, password: String? = nil,
         host: String = "localhost", port: Int32 = 1883) {

        let clientId = !cleanSess && (clientId == "") ? NSUUID().uuidString : clientId

        Config.sharedInstance.setUser(clientId: clientId, username: username, password: password)
        Config.sharedInstance.addBroker(host: host, port: port)

        readQueue = DispatchQueue(label: "read queue", attributes: DispatchQueue.Attributes.concurrent)
        writeQueue = DispatchQueue(label: "write queue", attributes: DispatchQueue.Attributes.concurrent)
        
        buffer = Data()
    }

    // Initial Connect
    public func connect(withSSL: Bool = false, certPath: String? = nil, keyPath: String? = nil) throws {
        
        #if os(OSX) || os(iOS)
            if socket == nil {
                //socket = try SocketFactory<MQTTStream>.sharedInstance()
                
                ///quick test using socket lib for unit tests
                socket = SocketFactory<SocketLayer>.sharedInstance()
            }
        #elseif os(Linux)
            if socket == nil {
                socket = SocketFactory<SocketLayer>.sharedInstance()
                try socket!.setBlocking(mode: false)
            }
        #endif
        
        #if os(OSX) || os(iOS)
            if let _socket = socket {
                do {
                    try _socket.connect(to: config.host, port: config.port, timeout:10)
                } catch _ {
                    print( "Error")
                }
                
            }
        #elseif os(Linux)
            try socket!.connect(to: config.host, port: config.port, timeout:10)
        #endif
        
        
        requestHandler(packet: ConnectPacket()) {
            self.startTimer()
            self.read()
            config.status = .connected
        }
    }

    public func reconnect() {
    }

    public func disconnect() {
        guard config.status != .disconnected else {
            print(Errors.alreadyDisconnected)
            return
        }

        requestHandler(packet: DisconnectPacket()) {
            config.status = .disconnected
            sleep(config.quiesce)   // Sleep to allow buffering packets to be sent
            self.socket?.close()
            self.buffer = Data()
            self.keepAliveTimer = nil
            self.delegate?.didLoseConnection(error: nil)
        }
    }

    public func publish(topic: String, withMessage message: String, qos: QosType = .atLeastOnce, retain: Bool = false) {

        guard topic.matches(pattern: config.publishPattern) else {
            print(Errors.invalidTopicName)
            return
        }

        let publishPacket = PublishPacket(topic: topic, message: message, dup: false, qos: qos, willRetain: retain)

        requestHandler(packet: publishPacket) {

            if qos ==  .atMostOnce{
                self.delegate?.didCompleteDelivery(token: String(publishPacket.identifier))
            }
        }
    }

    public func subscribe(topic: [String], qoss: [QosType]) {
        requestHandler(packet: SubscribePacket(topics: topic, qoss: qoss))
    }

    public func unsubscribe(topics: [String]) {
        requestHandler(packet: UnsubscribePacket(topics: topics))
    }

    public func ping() throws {
        requestHandler(packet: PingreqPacket())
    }
    
    internal func pubrel(packetId: UInt16) {
        requestHandler(packet: PubrelPacket(packetId: packetId))
    }

    internal func requestHandler(packet: ControlPacket, onCompletion: (()->())? = nil) {
        guard let sock = socket else {
            delegate?.didLoseConnection(error: Errors.socketNotOpen)
            return
        }

        var packet = packet

        writeQueue.async {
            do {
                try packet.write(writer: sock)

                switch packet {
                case is PingreqPacket   : break
                case is ConnectPacket   : break
                default                 : self.resetTimer()
                }
                
                if let onComp = onCompletion { onComp() }

            } catch {
                print(error)
            }
        }
    }
}

extension Sunapsis {

    public func setWill(topic: String, message: String? = nil, willQoS: QosType = .atMostOnce, willRetain: Bool = false) {
        config.will = LastWill(topic: topic, message: message, qos: willQoS, retain: willRetain)
    }

    internal func read() {

        guard let sock = socket else {
            delegate?.didLoseConnection(error: Errors.socketNotOpen)
            return
        }

        #if os(OSX) || os(iOS)
        //need code to read from stream?
        #elseif os(Linux)
        let iochannel = DispatchIO(type: DispatchIO.StreamType.stream, fileDescriptor: sock.socketfd, queue: readQueue, cleanupHandler: {
            error in
        })

        iochannel.read(offset: off_t(0), length: 1, queue: readQueue) {
            done, data, error in

            let bytes: [Byte]? = data?.map {
                byte in
                return byte
            }

            if let d = bytes {
                self.buffer.append(d, count: d.count)
                if self.buffer.count >= self.bound {
                    self.unpack()
                }
                self.read()
            }
        }
        #endif
    }

    internal func parseHeader() -> (Byte, Int)? {
        
        let controlByte: Byte = buffer[0]

        guard let length = decodeLength(buffer.subdata(in: Range(1..<bound))) else {
            return nil
        }

        return (controlByte, length)
    }

    internal func unpack() {
        
        while buffer.count >= bound  {

            // See if we have a header
            guard let (controlByte, bodyLength) = parseHeader() else {
                bound += 1
                return
            }
            // Do we have all the bytes we need for the full packet?
            let bytesNeeded = buffer.count - bodyLength - bound
            
            if bytesNeeded < 0 {
                return
            }

            let body = buffer.subdata(in: Range(bound..<bound + bodyLength))

            buffer = buffer.subdata(in: Range(bound + bodyLength..<buffer.count))

            guard let packet = newControlPacket(header: controlByte, bodyLength: bodyLength, data: body) else {
                print(Errors.unrecognizedOpcode)
                return
            }

            bound = 2

            switch packet {
            case _ as ConnackPacket     : delegate?.didConnect()
            case _ as PubackPacket      : delegate?.didCompleteDelivery(token: packet.description)
            case _ as PubcompPacket     : delegate?.didCompleteDelivery(token: packet.description)
            case let p as PublishPacket : delegate?.didReceiveMessage(topic: p.topic, message: p.message)
            case let p as PubrecPacket  :
                                          delegate?.didCompleteDelivery(token: packet.description)
                                          self.pubrel(packetId: p.packetId)
            default: delegate?.didCompleteDelivery(token: packet.description)
            }
        }
    }
}

extension Sunapsis {

    internal func startTimer() {

        keepAliveTimer = keepAliveTimer ?? DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags.strict, queue: writeQueue)

        keepAliveTimer?.scheduleRepeating(deadline: .now(), interval: .seconds(Int(config.keepAlive)), leeway: .milliseconds(500))

        keepAliveTimer?.setEventHandler {

            self.writeQueue.async {
                do {
                    try self.ping()

                } catch {
                    print("Error Sending Ping Request")
                }
            }
        }

        keepAliveTimer?.resume()

    }

    internal func resetTimer() {
        keepAliveTimer?.cancel()
        keepAliveTimer = nil
        startTimer()
    }
}
    
extension Sunapsis {
    internal func newControlPacket(header: Byte, bodyLength: Int, data: Data) -> ControlPacket? {

        guard let code: ControlCode = ControlCode(rawValue: (header & 0xF0)) else {
            print(Errors.unrecognizedOpcode)
            return nil
        }

        switch code {
        case .connect:
            return ConnectPacket(data: data)
        case .connack:
            return ConnackPacket(data: data)
        case .publish:
            return PublishPacket(header: header, bodyLength: bodyLength, data: data)
        case .puback:
            return PubackPacket(data: data)
        case .pubrec:
            return PubrecPacket(data: data)
        case .pubrel:
            return PubrelPacket(data: data)
        case .pubcomp:
            return PubcompPacket(data: data)
        case .subscribe:
            return SubscribePacket(data: data)
        case .suback:
            return SubackPacket(data: data)
        case .unsubscribe:
            return UnsubscribePacket(data: data)
        case .unsuback:
            return UnSubackPacket(data: data)
        case .pingreq:
            return PingreqPacket()
        case .pingresp:
            return PingrespPacket()
        case .disconnect:
            return DisconnectPacket(data: data)
        default:
            return ConnackPacket(data: data)
        }
    }
}
// SSL Certification Initialization: Must be called before connect
extension Sunapsis {

    public func setSSL(certPath: String? = nil, keyPath: String? = nil) throws {

        let SSLConfig = SSLService.Configuration(withCACertificateDirectory: nil, usingCertificateFile: certPath, withKeyFile: keyPath)
        
        config.SSLConfig = SSLConfig

        #if os(OSX) || os(iOS)

        #elseif os(Linux)
            if socket == nil { socket = try Socket.create(family: .inet6, type: .stream, proto: .tcp) }
            socket?.delegate = try SSLService(usingConfiguration: SSLConfig)
        #endif
    }

    public func setSSL(with ChainFilePath: String, usingSelfSignedCert: Bool) throws {

        let SSLConfig = SSLService.Configuration(withChainFilePath: ChainFilePath, usingSelfSignedCerts: usingSelfSignedCert)
        
        config.SSLConfig = SSLConfig

        #if os(OSX) || os(iOS)
            
        #elseif os(Linux)
            if socket == nil { socket = try Socket.create(family: .inet6, type: .stream, proto: .tcp) }
            socket?.delegate = try SSLService(usingConfiguration: SSLConfig)
        #endif
    }

    public func setSSL(with CACertificatePath: String?, using CertificateFile: String?, with KeyFile: String?, selfSignedCerts: Bool) throws {

        let SSLConfig = SSLService.Configuration(withCACertificateFilePath: CACertificatePath,
                                                usingCertificateFile: CertificateFile,
                                                withKeyFile: KeyFile,
                                                usingSelfSignedCerts: selfSignedCerts)
        config.SSLConfig = SSLConfig

        #if os(OSX) || os(iOS)
            
        #elseif os(Linux)
            if socket == nil { socket = try Socket.create(family: .inet6, type: .stream, proto: .tcp) }
            socket?.delegate = try SSLService(usingConfiguration: SSLConfig)
        #endif
    }
}
