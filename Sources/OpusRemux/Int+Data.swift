//
//  Int+Data.swift
//
//

import Foundation

extension Int {
    var data: Data {
        var value = self.bigEndian
        return .init(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

extension UInt32 {
    var data: Data {
        var value = self.bigEndian
        return .init(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

extension UInt16 {
    var data: Data {
        var value = self.bigEndian
        return .init(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

extension UInt64 {
    var data: Data {
        var value = self.bigEndian
        return .init(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

extension Int16 {
    var data: Data {
        var value = self.bigEndian
        return .init(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

extension Int32 {
    var data: Data {
        var value = self.bigEndian
        return .init(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
