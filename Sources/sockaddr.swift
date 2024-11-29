//  sockaddr.swift
//  Simplenet SocketAddress module
//  Copyright (c) 2018 Vladimir Raisov
//  Licensed under MIT License

import Darwin.POSIX

// MARK: - IP address extensions

extension in_addr {
    public static let family = AF_INET
    public static let wildcard = Self(s_addr: INADDR_ANY.bigEndian)
    public static let loopback = Self(s_addr: INADDR_LOOPBACK.bigEndian)
    public static let broadcast = Self(s_addr: INADDR_BROADCAST.bigEndian)
    public var isWildcard: Bool {self == Self.wildcard}
    public var isLoopback: Bool {self == Self.loopback}
    public var isMulticast: Bool {s_addr & 0xf0 == 0xe0}
    public var isLinkLocal: Bool {s_addr & 0xffff == IN_LINKLOCALNETNUM.bigEndian}

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
    public static let family = AF_INET6
    public static let wildcard = in6addr_any
    public static let loopback = in6addr_loopback
    public var isWildcard: Bool {self == in6addr_any}
    public var isLoopback: Bool {self == in6addr_loopback}
    public var isMulticast: Bool {self.__u6_addr.__u6_addr8.0 == 0xff}
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
    public static let family = in_addr.family
    public static let size = MemoryLayout<Self>.size
    public var family: Int32 { numericCast(sin_family) }
    
    public var isWellFormed: Bool {
        family == Self.family &&
        sin_len <= Self.size &&
        sin_len > MemoryLayout<sockaddr_in>.offset(of: \.sin_addr)!
    }
    
    public var isWildcard: Bool {isWellFormed && sin_addr.isWildcard }
    public var isLoopback: Bool {isWellFormed && sin_addr.isLoopback }
    public var isMulticast: Bool {isWellFormed && sin_addr.isMulticast }
    public var isLinkLocal: Bool {isWellFormed && sin_addr.isLinkLocal }
}

extension sockaddr_in {
    public init(_ address: in_addr = in_addr(s_addr: INADDR_ANY), port: UInt16) {
        self.init(sin_len: __uint8_t(Self.size),
                  sin_family: sa_family_t(Self.family),
                  sin_port: port.bigEndian,
                  sin_addr: address,
                  sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }
}

extension sockaddr_in6 {
    public static let family = in6_addr.family
    public var family: Int32 { numericCast(sin6_family) }
    public static let size = MemoryLayout<Self>.size

    public var isWellFormed: Bool {
        family == Self.family && sin6_len == Self.size
    }
    
    public var isWildcard: Bool {isWellFormed && sin6_addr.isWildcard }
    public var isLoopback: Bool {isWellFormed && sin6_addr.isLoopback }
    public var isMulticast: Bool {isWellFormed && sin6_addr.isMulticast }
    public var isLinkLocal: Bool {isWellFormed && sin6_addr.isLinkLocal }
}

extension sockaddr_in6 {
    public init(_ address: in6_addr = in6addr_any, port: UInt16, flowinfo: UInt32 = 0, scope: UInt32 = 0) {
        self.init(sin6_len: __uint8_t(Self.size),
                  sin6_family: sa_family_t(Self.family),
                  sin6_port: port.bigEndian,
                  sin6_flowinfo: flowinfo,
                  sin6_addr: address,
                  sin6_scope_id: scope
        )
    }
}

extension sockaddr_dl {
    public static let family = AF_LINK
    public var family: Int32 { numericCast(sdl_family) }
    public static let size = MemoryLayout<Self>.size
    
    public var isWellFormed: Bool {
        family == Self.family &&
        sdl_len <= Self.size &&
        sdl_len >= headerSize + Int(sdl_alen + sdl_nlen + sdl_slen)
    }
    
    var headerSize: Int { Self.size - MemoryLayout.size(ofValue: sdl_data) }
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
    public var sin: sockaddr_in? {
        guard withMemoryRebound(to: sockaddr_in.self, capacity: 1, {
            $0.pointee.isWellFormed
        }) else { return nil }
        
        var sin = sockaddr_in()
        return withUnsafeMutablePointer(to: &sin) {
            let sin_p = UnsafeMutableRawPointer($0)
            sin_p.copyMemory(from: self, byteCount: Int(pointee.sa_len))
            sin_p.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_len = numericCast(sockaddr_in.size)
            return sin_p.assumingMemoryBound(to: sockaddr_in.self).pointee
        }
    }
    
    public var sin6: sockaddr_in6? {
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
    public var sin: sockaddr_in? {
        return UnsafePointer(self).sin
    }
    
    public var sin6: sockaddr_in6? {
        return UnsafePointer(self).sin6
    }
    
    public var dl: sockaddr_dl? {
        return UnsafePointer(self).dl
    }
}

// MARK: - sockaddr_storage extensions

extension sockaddr_storage {
    public static let size = MemoryLayout<Self>.size
}

extension sockaddr_storage {
    public init(_ sin: sockaddr_in) {
        self.init()
        withUnsafeMutableBytes(of: &self) {
            let sin_p = $0.baseAddress!.assumingMemoryBound(to: sockaddr_in.self)
            sin_p.pointee = sin
        }
    }
    
    public init(_ sin6: sockaddr_in6) {
        self.init()
        withUnsafeMutableBytes(of: &self) {
            let sin6_p = $0.baseAddress!.assumingMemoryBound(to: sockaddr_in6.self)
            sin6_p.pointee = sin6
        }
    }
    
    /// Create `sockaddr_strorage` containing result of BSD functions such as `getsockname`, `getpeername`
    /// - Rarameters:
    ///     - body: Closure that takes a pointer to the memory buffer to place
    ///             the returned sockaddr and a pointer to socklen_t variable
    ///             to place returned sockaddr length.
    /// - Returns: `sockaddr_storage` with results of `body` execution.
    public init(_ body: (
        UnsafeMutablePointer<sockaddr>,
        UnsafeMutablePointer<socklen_t>
    ) throws -> Int32) rethrows {
        self.init()
        var length = socklen_t(Self.size)
        try withUnsafeMutableBytes(of: &self) {
            let sa_p = $0.baseAddress!.assumingMemoryBound(to: sockaddr.self)
            _ = try body(sa_p, &length)
        }
        assert(ss_len == length)
    }
}

extension sockaddr_storage {
    public var sin: sockaddr_in? {
        withUnsafeBytes(of: self) {
            $0.baseAddress?.assumingMemoryBound(to: sockaddr.self).sin
        }
    }
    
    public var sin6: sockaddr_in6? {
        withUnsafeBytes(of: self) {
            $0.baseAddress?.assumingMemoryBound(to: sockaddr.self).sin6
        }
    }

    public var dl: sockaddr_dl? {
        withUnsafeBytes(of: self) {
            $0.baseAddress?.assumingMemoryBound(to: sockaddr.self).dl
        }
    }
    
    /// Executes BSD functions such as `bind`, `connect` or `sendto` 
    /// with a `sockaddr` pointer as input parameter;
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

