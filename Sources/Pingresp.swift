/**
 Copyright IBM Corporation 2016
 
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
import Socket


class PingrespPacket {
    let header: FixedHeader

    init(header: FixedHeader) {
        self.header = header
    }
}

extension PingrespPacket: ControlPacket {
    var description: String {
        return header.description
    }

    func write(writer: SocketWriter) throws {
        let packet = header.pack()
        try writer.write(from: packet)
    }

    func unpack(reader: SocketReader) {
    }

    func validate() -> ErrorCodes {
        return .accepted
    }
}