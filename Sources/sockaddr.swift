//  sockaddr.swift
//  Simplenet SocketAddress module
//  Copyright (c) 2018 Vladimir Raisov
//  Licensed under MIT License

import Darwin.POSIX

/// Address families, the same as protocol families.
public enum SocketAddressFamily: RawRepresentable {
    /// Unix pipe
    case unix
    /// IPv4
    case inet
    /// IPv6
    case inet6
    /// Link layer interface
    case link

    public init?(rawValue: Int32) {
        switch rawValue {
        case AF_UNIX: self = .unix
        case AF_INET: self = .inet
        case AF_INET6: self = .inet6
        case AF_LINK: self = .link
        default:
            return nil
        }
    }

    public var rawValue: Int32 {
        switch self {
        case .unix: return AF_UNIX
        case .inet: return AF_INET
        case .inet6: return AF_INET6
        case .link: return AF_LINK
        }
    }
}

// IP address family.
public enum IPFamily: RawRepresentable {
    case ip4, ip6
    public init?(rawValue: Int32) {
        switch rawValue {
        case AF_INET: self = .ip4
        case AF_INET6: self = .ip6
        default:
            return nil
        }
    }

    public var rawValue: Int32 {
        switch self {
        case .ip4: return AF_INET
        case .ip6: return AF_INET6
        }
    }
}

// Casts `IPFamily` to `SocketAddressFamily`.
extension SocketAddressFamily {
    public init(_ family: IPFamily) {
        self.init(rawValue: family.rawValue)!
    }
}

// MARK: in_addr extensions
extension in_addr {
    public static var family: IPFamily  {return .ip4}
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

// MARK: in6_addr extensions
extension in6_addr {
    public static var family: IPFamily  {return .ip6}
    public var isWildcard: Bool {return self == in6addr_any}
    public var isLoopback: Bool {return self == in6addr_loopback}
    public var isMulticast: Bool {return self.__u6_addr.__u6_addr8.0 == 0xff}
    

    public func with(port: UInt16 = 0) -> sockaddr_in6 {
        return sockaddr_in6(self, port: port)
    }
}

extension in6_addr {
    public var isLinkLocal: Bool { (self.__u6_addr.__u6_addr16.0 & 0xc0fe) == 0x80fe}
}

extension in6_addr: @retroactive Equatable {
    public static func == (lhs: in6_addr, rhs: in6_addr) -> Bool {
        return lhs.__u6_addr.__u6_addr32 == rhs.__u6_addr.__u6_addr32
    }
}


// MARK: sockaddr_in extensions
extension sockaddr_in {
    public init(_ address: in_addr = in_addr(s_addr: INADDR_ANY), port: UInt16) {
        self.init(sin_len: __uint8_t(MemoryLayout<sockaddr_in>.size),
                  sin_family: sa_family_t(AF_INET),
                  sin_port: port.byteSwapped,
                  sin_addr: address,
                  sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }
}

// MARK: sockaddr_in6 extensions
extension sockaddr_in6 {
    public init(_ address: in6_addr = in6addr_any, port: UInt16, flowinfo: UInt32 = 0, scope: UInt32 = 0) {
        self.init(sin6_len: __uint8_t(MemoryLayout<sockaddr_in6>.size),
                  sin6_family: sa_family_t(AF_INET6),
                  sin6_port: port.byteSwapped,
                  sin6_flowinfo: flowinfo,
                  sin6_addr: address,
                  sin6_scope_id: scope
        )
    }
}

// MARK: sockaddr_storage extensions
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

// MARK: sockaddr_dl extensions
extension sockaddr_dl {
    public var family: SocketAddressFamily? {return SocketAddressFamily(rawValue: numericCast(self.sdl_family))}
    public var isWellFormed: Bool {
        sdl_family == AF_LINK &&
        sdl_len >= self.headerSize + Int(self.sdl_alen + self.sdl_nlen + self.sdl_slen)
    }
}

extension sockaddr_dl {
    public var index: UInt32 {return numericCast(self.sdl_index)}
    public var type: Int32 {return numericCast(self.sdl_type)}
    var headerSize: Int {return MemoryLayout<sockaddr_dl>.size - MemoryLayout.size(ofValue: self.sdl_data)}
}

extension UnsafePointer where Pointee == sockaddr_dl {
    public var length: Int { Int(self.pointee.sdl_len) }
    public var index: UInt32 { (self.pointee.index) }
    public var type: Int32 { (self.pointee.type) }
    
    public var name: String {
        guard self.pointee.isWellFormed else {return ""}
        return self.withMemoryRebound(to: CChar.self, capacity: self.length) {
            // some extra code to eliminate using NSString
            var name = [CChar](repeating: 0, count: Int(self.pointee.sdl_nlen) + 1)
            for i in 0..<Int(self.pointee.sdl_nlen) {
                name[i] = $0.advanced(by: self.pointee.headerSize + i).pointee
            }
            return String(cString: &name)
        }
    }

    public var address: [UInt8] {
        guard Int(self.pointee.sdl_len) >=
            self.pointee.headerSize +
            Int(self.pointee.sdl_alen + self.pointee.sdl_nlen + self.pointee.sdl_slen)
            else {return []}
        return self.withMemoryRebound(to: UInt8.self, capacity: self.length) {
            Array(UnsafeBufferPointer(start: $0.advanced(by: self.pointee.headerSize + Int(self.pointee.sdl_nlen)),
                                      count: Int(self.pointee.sdl_alen)))
        }
    }
}

extension UnsafeMutablePointer where Pointee == sockaddr_dl {
    public var name: String {return UnsafePointer(self).name}
    public var address: [UInt8] {return UnsafePointer(self).address}
}

// MARK: sockaddr extensions
extension UnsafePointer where Pointee == sockaddr {
    public var `in`: sockaddr_in? {
        guard pointee.sa_family == AF_INET else { return nil }
        assert(pointee.sa_len <= MemoryLayout<sockaddr_in>.size, "malformed sockaddr")
        guard pointee.sa_len <= MemoryLayout<sockaddr_in>.size else { return nil }
        assert(pointee.sa_len > MemoryLayout<sockaddr_in>.offset(of: \.sin_addr)!, "malformed sockaddr")
        guard pointee.sa_len > MemoryLayout<sockaddr_in>.offset(of: \.sin_addr)! else { return nil }
        var sin = sockaddr_in()
        return withUnsafeMutablePointer(to: &sin) {
            let sin_p = UnsafeMutableRawPointer($0)
            sin_p.copyMemory(from: self, byteCount: Int(pointee.sa_len))
            sin_p.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_len = numericCast(MemoryLayout<sockaddr_in>.size)
            return sin_p.assumingMemoryBound(to: sockaddr_in.self).pointee
        }
    }
    
    public var in6: sockaddr_in6? {
        guard pointee.sa_family == AF_INET6 else { return nil }
        assert(pointee.sa_len == MemoryLayout<sockaddr_in6>.size, "malformed sockaddr")
        guard pointee.sa_len <= MemoryLayout<sockaddr_in6>.size else { return nil }
        var sin6 = sockaddr_in6()
        return self.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
            $0.pointee
        }
    }
    
    public var dl: sockaddr_dl? {
        guard pointee.sa_family == AF_LINK else { return nil }
        assert(pointee.sa_len >= MemoryLayout<sockaddr_dl>.size, "malformed sockaddr")
        guard pointee.sa_len >= MemoryLayout<sockaddr_dl>.size else { return nil }
        var sdl = sockaddr_dl()
        return self.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
            $0.pointee
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
}

