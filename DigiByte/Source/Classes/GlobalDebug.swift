//
//  GlobalDebug.swift
//  DigiByte
//
//  Created by Yoshi Jäger on 11.06.20.
//  Copyright © 2020 DigiByte Foundation NZ Limited. All rights reserved.
//

import Foundation

fileprivate let RING_BUFFER_SIZE = 2048

class GlobalDebug {
    public static let `default` = GlobalDebug()
    public var ringBuffer = [String?](repeating: nil, count: RING_BUFFER_SIZE)
    public var tsRingBuffer = [Date?](repeating: nil, count: RING_BUFFER_SIZE)
    public var index: Int = 0
    
    private init() {
        ringBuffer.reserveCapacity(RING_BUFFER_SIZE)
        tsRingBuffer.reserveCapacity(RING_BUFFER_SIZE)
    }
    
    func add(_ str: String) {
        let ts = Date()
        ringBuffer[index] = str
        tsRingBuffer[index] = ts
        index = (index + 1) % RING_BUFFER_SIZE
        
        print("Debug: \(str)\n")
    }
    
    func serialize() -> String {
        var output = ""
        var it = index + 1
        
        while it != index {
            if
                let str = ringBuffer[it],
                let ts = tsRingBuffer[it]
            {
                output = output + "\(ts): \(str)\n"
            }
            
            it = (it + 1) % RING_BUFFER_SIZE
        }
        
        return output
    }
}
