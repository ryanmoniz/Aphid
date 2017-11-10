//
//  SocketFactory.swift
//
//  Created by Ryan Moniz on 2017-06-02.
//  Copyright © IBM Corp. 2017. All rights reserved.
//

import Foundation

private var singleton_map: [String : SocketBackend] = [String : SocketBackend]()
private var singleton_queue = DispatchQueue(label:"com.ibm.Sunapsis")


struct SocketFactory<T: SocketBackend> {
    static func sharedInstance() -> T {
        var dev: T?
        
        singleton_queue.sync() {
            let identifier = T.className()
            var singleton: T? = singleton_map[identifier] as? T
            if singleton == nil {
                singleton = T()
                singleton_map.updateValue(singleton!, forKey: identifier)
            }
            
            dev = singleton
        }
        
        return dev!
    }
}
