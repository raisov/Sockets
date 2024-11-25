//  sockaddr.swift
//  Simplenet SocketAddress module
//  Copyright (c) 2018 Vladimir Raisov
//  Licensed under MIT License

import Darwin.POSIX

// MARK: - IP address extensions

extension in_addr {
    public static var family: Int32 { AF_INET }
    public var isWildcard: Bool {return self.s_addr == INADDR_ANY.bigEndian}
    public var isLoopback: Bool {return self.s_addr == INADDR_LOOPBACK.bigEndian}
    public var isMulticast: Bool {return (self.s_addr & 0xf0) == 0xe0}

    public func with(port: UInt16 = 0) -> sockaddr_in {
        return sockaddr_in(self, port: port)
    }
}

extension in_addr: @retroactive Equatable {
    public static func == (lhs: in_addr, rhs: in_addr) -> Bool {
        return lhs.s_addr == rhs.s_addr
    }
}

extension in6_addr {
    public static var family: Int32 { AF_INET6 }
    public var isWildcard: Bool {return self == in6addr_any}
    public var isLoopback: Bool {return self == in6addr_loopback}
    public var isMulticast: Bool {return self.__u6_addr.__u6_addr8.0 == 0xff}
    public var isLinkLocal: Bool { (self.__u6_addr.__u6_addr16.0 & 0xc0fe) == 0x80fe}
    

    public func with(port: UInt16 = 0) -> sockaddr_in6 {
        return sockaddr_in6(self, port: port)
    }
}

extension in6_addr: @retroactive Equatable {
    public static func == (lhs: in6_addr, rhs: in6_addr) -> Bool {
        return lhs.__u6_addr.__u6_addr32 == rhs.__u6_addr.__u6_addr32
    }
}


// MARK: - sockaddr_* extensions

extension sockaddr_in {
    public static var family: Int32 { in_addr.family }
    public var family: Int32 { numericCast(sin_family) }
    
    public var isWellFormed: Bool {
        family == Self.family &&
        sin_len <= MemoryLayout<Self>.size &&
        sin_len > MemoryLayout<sockaddr_in>.offset(of: \.sin_addr)!
    }
    
    public var isWildcard: Bool {isWellFormed && sin_addr.isWildcard }
    public var isLoopback: Bool {isWellFormed && sin_addr.isLoopback }
    public var isMulticast: Bool {isWellFormed && sin_addr.isMulticast }
}

extension sockaddr_in {
    public init(_ address: in_addr = in_addr(s_addr: INADDR_ANY), port: UInt16) {
        self.init(sin_len: __uint8_t(MemoryLayout<sockaddr_in>.size),
                  sin_family: sa_family_t(Self.family),
                  sin_port: port.byteSwapped,
                  sin_addr: address,
                  sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }
}

extension sockaddr_in6 {
    public static var family: Int32 { in6_addr.family }
    public var family: Int32 { numericCast(sin6_family) }
    
    public var isWellFormed: Bool {
        family == Self.family && sin6_len == MemoryLayout<Self>.size
    }
    
    public var isWildcard: Bool {isWellFormed && sin6_addr.isWildcard }
    public var isLoopback: Bool {isWellFormed && sin6_addr.isLoopback }
    public var isMulticast: Bool {isWellFormed && sin6_addr.isMulticast }
    public var isLinkLocal: Bool {isWellFormed && sin6_addr.isLinkLocal }
}

extension sockaddr_in6 {
    public init(_ address: in6_addr = in6addr_any, port: UInt16, flowinfo: UInt32 = 0, scope: UInt32 = 0) {
        self.init(sin6_len: __uint8_t(MemoryLayout<sockaddr_in6>.size),
                  sin6_family: sa_family_t(Self.family),
                  sin6_port: port.byteSwapped,
                  sin6_flowinfo: flowinfo,
                  sin6_addr: address,
                  sin6_scope_id: scope
        )
    }
}

extension sockaddr_dl {
    public static var family: Int32 { AF_LINK }
    public var family: Int32 { numericCast(sdl_family) }
    public var isWellFormed: Bool {
        family == Self.family &&
        sdl_len <= MemoryLayout<Self>.size &&
        sdl_len >= headerSize + Int(sdl_alen + sdl_nlen + sdl_slen)
    }
    var headerSize: Int {return MemoryLayout<sockaddr_dl>.size - MemoryLayout.size(ofValue: self.sdl_data)}
}

extension sockaddr_dl {
    public var index: UInt32 {return numericCast(self.sdl_index)}
    public var type: Int32 {return numericCast(self.sdl_type)}
}

extension UnsafePointer where Pointee == sockaddr_dl {
    public var length: Int { Int(pointee.sdl_len) }
    public var index: UInt32 { (pointee.index) }
    public var type: Int32 { (pointee.type) }
    
    public var name: String {
        guard pointee.isWellFormed else {return ""}
        return withMemoryRebound(to: CChar.self, capacity: self.length) {
            // some extra code to eliminate using NSString
            var name = [CChar](repeating: 0, count: Int(pointee.sdl_nlen) + 1)
            for i in 0..<Int(pointee.sdl_nlen) {
                name[i] = $0.advanced(by: pointee.headerSize + i).pointee
            }
            return String(cString: &name)
        }
    }

    public var address: [UInt8] {
        guard length >=
            pointee.headerSize + Int(pointee.sdl_alen + pointee.sdl_nlen + pointee.sdl_slen) else {return []}
        return self.withMemoryRebound(to: UInt8.self, capacity: self.length) {
            Array(
                UnsafeBufferPointer(
                    start: $0.advanced(by: pointee.headerSize + Int(pointee.sdl_nlen)),
                    count: Int(pointee.sdl_alen)
                )
            )
        }
    }
}

extension UnsafeMutablePointer where Pointee == sockaddr_dl {
    public var name: String {return UnsafePointer(self).name}
    public var address: [UInt8] {return UnsafePointer(self).address}
}

// MARK: - sockaddr extensions

extension UnsafePointer where Pointee == sockaddr {
    public var `in`: sockaddr_in? {
        guard withMemoryRebound(to: sockaddr_in.self, capacity: 1, {
            $0.pointee.isWellFormed
        }) else { return nil }
        
        var sin = sockaddr_in()
        return withUnsafeMutablePointer(to: &sin) {
            let sin_p = UnsafeMutableRawPointer($0)
            sin_p.copyMemory(from: self, byteCount: Int(pointee.sa_len))
            sin_p.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_len = numericCast(MemoryLayout<sockaddr_in>.size)
            return sin_p.assumingMemoryBound(to: sockaddr_in.self).pointee
        }
    }
    
    public var in6: sockaddr_in6? {
        self.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
            $0.pointee.isWellFormed ? $0.pointee : nil
        }
    }
    
    public var dl: sockaddr_dl? {
        self.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
            $0.pointee.isWellFormed ? $0.pointee : nil
        }
    }
}

extension UnsafeMutablePointer where Pointee == sockaddr {
    public var `in`: sockaddr_in? {
        return UnsafePointer(self).in
    }
    
    public var in6: sockaddr_in6? {
        return UnsafePointer(self).in6
    }
    
    public var dl: sockaddr_dl? {
        return UnsafePointer(self).dl
    }
}

// MARK: - sockaddr_storage extensions

extension sockaddr_storage {
    public init(_ sin: sockaddr_in) {
        self.init()
        try withUnsafeMutableBytes(of: &self) {
            let sin_p = $0.baseAddress!.assumingMemoryBound(to: sockaddr_in.self)
            sin_p.pointee = sin
        }
    }
    
    public init(_ sin6: sockaddr_in6) {
        self.init()
        try withUnsafeMutableBytes(of: &self) {
            let sin6_p = $0.baseAddress!.assumingMemoryBound(to: sockaddr_in6.self)
            sin6_p.pointee = sin6
        }
    }
}

extension sockaddr_storage {
    public var `in`: sockaddr_in? {
        withUnsafeBytes(of: self) {
            $0.baseAddress?.assumingMemoryBound(to: sockaddr.self).in
        }
    }
    
    public var in6: sockaddr_in6? {
        withUnsafeBytes(of: self) {
            $0.baseAddress?.assumingMemoryBound(to: sockaddr.self).in6
        }
    }

    public var dl: sockaddr_dl? {
        withUnsafeBytes(of: self) {
            $0.baseAddress?.assumingMemoryBound(to: sockaddr.self).dl
        }
    }
    
    /// Executes functions with a `sockaddr` pointer as input parameter;
    /// such as `bind`, `connect` or `sendto`.
    /// - parameter body: A closure that takes a sockaddr pointer and sockaddr length as input parameters.
    /// - Returns: the return value of the `body`.
    @discardableResult
    public func withSockaddrPointer<ResultType>(_ body: (
        UnsafePointer<sockaddr>
    ) throws -> ResultType) rethrows -> ResultType {
        try withUnsafeBytes(of: self) {
            let sa_p =   $0.baseAddress!.assumingMemoryBound(to: sockaddr.self)
            return try body(sa_p)
        }
    }
}

