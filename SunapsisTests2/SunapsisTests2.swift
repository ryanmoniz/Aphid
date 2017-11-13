//
//  SunapsisTests2.swift
//  SunapsisTests2
//
//  Created by Ryan Moniz on 2017-11-10.
//

import XCTest
@testable import Sunapsis

#if os(OSX) || os(iOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

class SunapsisTests2: XCTestCase,MQTTDelegate {
        private var sunapsis: Sunapsis!
        
        var testCase = ""
        var receivedCount = 0
        
        let topic = "plants/basilplant"
        
        let message = "{\"payload\":\"An5oww==\",\"fields\":{\"beaconId\":2,\"humidy\":55.5234375,\"temp\":24.536250000000003},\"port\":1,\"counter\":633,\"dev_eui\":\"C0EE400001010916\",\"metadata\":[{\"frequency\":868.1,\"datarate\":\"SF12BW125\",\"codingrate\":\"4/5\",\"gateway_timestamp\":2806201428,\"gateway_time\":\"2016-08-11T16:16:01.687021Z\",\"channel\":0,\"server_time\":\"2016-08-11T16:16:01.710438775Z\",\"rssi\":-30,\"lsnr\":9.8,\"rfchain\":1,\"crc\":1,\"modulation\":\"LORA\",\"gateway_eui\":\"B827EBFFFEC139EF\",\"altitude\":8,\"longitude\":-1.7645,\"latitude\":54.9837}]}"
        
        weak var expectation: XCTestExpectation!
        weak var disconnectExpectation: XCTestExpectation!
        
        var tokens = [String]()
        
        static var allTests: [(String, (SunapsisTests2) -> () throws -> Void)] {
            return [
                ("testConnect", testConnect),
                ("testKeepAlive", testKeepAlive),
                ("testSubscribePublish", testSubscribePublish),
                ("testQosExactlyOnce",testQosExactlyOnce),
            ]
        }
        
        override func setUp() {
            super.setUp()
            
            //localhost with mosquitto
            let clientId = "d:h1xzer:unit_test:sunapsis_simulator_test"
            sunapsis = Sunapsis(clientId: clientId, cleanSess: true, username: nil, password: nil, host: "localhost", port: 1883)
            
            //watson IoT
            //let clientId = "d:h1xzer:unit_test:sunapsis_simulator_test"
            //sunapsis = Sunapsis(clientId: clientId, cleanSess: true, username: "use-token-auth", password: "PtBVriRqIg4uh", host: "h1xzer.messaging.internetofthings.ibmcloud.com", port: 1883)
            
            sunapsis.setWill(topic: "lastWillAndTestament/",message: "Client \(clientId) Closed Unexpectedly", willQoS: .atMostOnce, willRetain: false)
            
            sunapsis.delegate = self
            
        }
        
        func testConnect() throws {
            
            testCase = "connect"
            expectation = expectation(description: "Received Connack")
            do {
                try sunapsis.connect()
            } catch {
                expectation.fulfill()
                print("Error: \(error.localizedDescription)")
                XCTFail()
            }
            waitForExpectations(timeout: 30) {
                error in
                
                error != nil ? print("Error: \(error!.localizedDescription)") : self.disconnect()
            }
        }
        
        func testKeepAlive() throws {
            
            testCase = "ping"
            receivedCount = 0
            expectation = expectation(description: "Keep Alive Ping")
            do {
                try sunapsis.connect()
            } catch {
                expectation.fulfill()
                print("Error: \(error.localizedDescription)")
                XCTFail()
            }
            waitForExpectations(timeout: 90) {
                error in
                
                error != nil ? print("Error: \(error!.localizedDescription)") : self.disconnect()
            }
        }
        
        func testSubscribePublish() throws {
            
            testCase = "SubscribePublish"
            expectation = expectation(description: "Received a message")
            do {
                
                try sunapsis.connect()
                
                sunapsis.subscribe(topic: [topic], qoss: [.exactlyOnce])
                
                sunapsis.publish(topic: topic, withMessage: message, qos: QosType.exactlyOnce)
            } catch {
                expectation.fulfill()
                print("Error: \(error.localizedDescription)")
                XCTFail()
                
            }
            waitForExpectations(timeout: 60) {
                error in
                
                error != nil ? print("Error: \(error!.localizedDescription)") : self.disconnect()
            }
        }
        
        func testQosExactlyOnce() throws {
            
            testCase = "qos 2"
            receivedCount = 0
            expectation = expectation(description: "Received message exactly Once")
            
            do {
                try sunapsis.connect()
                
                sunapsis.subscribe(topic: [topic], qoss: [.exactlyOnce])
                
                sunapsis.publish(topic: topic, withMessage: message, qos: .exactlyOnce)
            } catch {
                expectation.fulfill()
                print("Error: \(error.localizedDescription)")
                XCTFail()
            }
            
            waitForExpectations(timeout: 30) {
                error in
                
                error != nil ? print("Error: \(error!.localizedDescription)") : self.disconnect()
            }
        }
        
        func disconnect() {
            disconnectExpectation = expectation(description: "Disconnected")
            
            sunapsis.disconnect()
            
            waitForExpectations(timeout: 20) {
                error in
                
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
        // Protocol Functions
        func didLoseConnection(error: Error?) {
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
            disconnectExpectation.fulfill()
        }
        
        func didConnect() {
            if testCase == "connect"  && receivedCount == 0{
                receivedCount += 1
                expectation.fulfill()
            }
        }
        
        func didCompleteDelivery(token: String) {
            if testCase == "ping" && token == "pingresp" {
                receivedCount += 1
                if receivedCount >= 3 {
                    expectation.fulfill()
                }
            } else if testCase == "qos 2" && (token == "pubrec" ||
                token == "pubcomp") && !tokens.contains(token) {
                tokens.append(token)
                if tokens.count == 2 {
                    expectation.fulfill()
                }
            }
        }
        
        func didReceiveMessage(topic: String, message: String) {
            if testCase == "SubscribePublish" {
                expectation.fulfill()
            }
        }
}

