//  Socket.swift
//  Sockets package
//  Copyright (c) 2018 Vladimir Raisov
//  Licensed under MIT License

import Darwin.POSIX
import struct Foundation.Data
import AddressFamily
import IPProtocol
import SocketType

/// Simply wraps the raw socket handle to create
/// namespace for socket related functions
/// and for using Swift memory management
/// to control socket life time.
public class Socket {

    /// Native socket handle
    fileprivate let handle: Int32

    /// Creates Socket by duplicating given handle.
    /// - Parameter handle: active socket descriptor.
    /// - Throws: SocketError (.badDescriptor or .tooManyDescriptors)
    public required init(_ handle: Int32) throws {
        self.handle = try bsd(Darwin.dup(handle))
    }

    /// Creates Socket from scratch.
    /// - Parameters:
    ///     - family: selects the protocol family which should be used;
    ///       has a same values as a socket address family.
    ///     - type: specifies the mode of socket communication.
    ///     - protocol: communication protocol to be used; when omitted is
    ///                 determined by the values of `type` and` family`.
    /// - Throws: SocketError.
    /// - SeeAlso: man 2 socket.
    public init(family: AddressFamily, type: SocketType = .datagram, protocol: IPProtocol? = nil) throws {
        self.handle = try bsd(Darwin.socket(family.rawValue, type.rawValue, `protocol`?.rawValue ?? 0))
    }

    /// Duplicate self socket descriptor for external use.
    /// - Returns: duplicated socket descriptor.
    /// - Throws: SocketError .tooManyDescriptor.
    public func duplicateDescriptor() throws -> Int32 {
        return try bsd(Darwin.dup(self.handle))
    }

    deinit {
        close(self.handle)
    }
}

extension Socket {
    /// Address bound to socket
    public var localAddress: sockaddr_storage? {
        try? sockaddr_storage { sa_p, length_p in
            try bsd(getsockname(self.handle, sa_p, length_p))
        }
    }

    ///address to which the socket is connected
    public var remoteAddress: sockaddr_storage? {
        try? sockaddr_storage { sa_p, length_p in
            try bsd(getpeername(self.handle, sa_p, length_p))
        }
    }

    public func bind(_ address: UnsafePointer<sockaddr>) throws {
        let length = socklen_t(address.pointee.sa_len)
        try bsd(Darwin.bind(self.handle, address, length))
    }

    public func connectTo(_ address: UnsafePointer<sockaddr>) throws {
        let length = socklen_t(address.pointee.sa_len)
        try bsd(Darwin.connect(self.handle, address, length))
    }

    @discardableResult
    public func sendTo(_ address: UnsafePointer<sockaddr>, data: Data, flags: Int32 = 0) throws -> Int {
        return try data.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: Int8.self)
            let length = socklen_t(address.pointee.sa_len)
            return try bsd(Darwin.sendto(self.handle, p, data.count, flags, address, length))
        }
    }

    @discardableResult
    public func send(_ data: Data, flags: Int32 = 0) throws -> Int {
        return try data.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: Int8.self)
            return try bsd(Darwin.send(self.handle, p, data.count, flags))
        }
    }
}

extension Socket {
    /// Get/set socket non blocking mode.
    /// True if socket is in asynchronous (non blocking) mode.
    public var nonBlockingOperations: Bool {
        get {
            let flags = try! bsd(fcntl(self.handle, F_GETFL))
            return (flags & O_NONBLOCK) != 0
        }

        set {
            var flags = try! bsd(fcntl(self.handle, F_GETFL))
            flags = newValue ? flags | O_NONBLOCK : flags & ~O_NONBLOCK
            try! bsd(fcntl(self.handle, F_SETFL, flags))
        }
    }
}

extension Socket {

    /// Get the value of an integer socket option.
    /// - Parameters:
    ///     - option: option code.
    ///     - level: SOL_SOCKET for socket level options or protocol number.
    /// - Returns: option value.
    /// - Throws: SocketError.
    /// - Notes: For socket level options, see `man 2 setsockopt`.
    ///          for IPPROTO_IP level see `man 4 ip`;
    ///          for IPPROTO_IPV6 see `man 4 ip6`.
    public func get(option: Int32, level: Int32) throws -> Int32 {
        var v = Int32(0)
        var l = socklen_t(MemoryLayout.size(ofValue: v))
        try bsd(getsockopt(self.handle, level, option, &v, &l))
        return v
    }

    /// Set the value of an integer socket option.
    /// - Parameters:
    ///     - option: option code.
    ///     - level: SOL_SOCKET for socket level options or protocol number.
    ///     - value: new value for option.
    /// - Throws: SocketError.
    /// - Notes: For socket level options, see `man 2 setsockopt`.
    ///          for IPPROTO_IP level see `man 4 ip`;
    ///          for IPPROTO_IPV6 see `man 4 ip6`.
    public func set(option: Int32, level: Int32, value: Int32) throws {
        var v = value
        let length = socklen_t(MemoryLayout.size(ofValue: value))
        try bsd(setsockopt(self.handle, level, option, &v, length))
    }

    /// Set the boolean socket option to `true`.
    /// - Parameters:
    ///     - option: option code.
    ///     - level: SOL_SOCKET for socket level options or protocol number.
    /// - Throws: SocketError.
    /// - Notes: For socket level options, see `man 2 setsockopt`.
    ///          for IPPROTO_IP level see `man 4 ip`;
    ///          for IPPROTO_IPV6 see `man 4 ip6`.
    public func enable(option: Int32, level: Int32) throws {
        try self.set(option: option, level: level, value: 1)
    }

    /// Set the boolean socket option to `false`.
    /// - Parameters:
    ///     - option: option code.
    ///     - level: SOL_SOCKET for socket level options or protocol number.
    /// - Throws: SocketError.
    /// - Notes: For socket level options, see `man 2 setsockopt`.
    ///          for IPPROTO_IP level see `man 4 ip`;
    ///          for IPPROTO_IPV6 see `man 4 ip6`.
    public func disable(option: Int32, level: Int32) throws {
        try self.set(option: option, level: level, value: 0)
    }


    /// Get the boolean socket option value.
    /// - Parameters:
    ///     - option: option code.
    ///     - level: SOL_SOCKET for socket level options or protocol number.
    /// - Returns: option value.
    /// - Throws: SocketError.
    /// - Notes: For socket level options, see `man 2 setsockopt`.
    ///          for IPPROTO_IP level see `man 4 ip`;
    ///          for IPPROTO_IPV6 see `man 4 ip6`.
    public func enabled(option: Int32, level: Int32) throws -> Bool {
        return try self.get(option: option, level: level) != 0
    }
}

extension Socket {
    /// Join to  multicast group.
    /// - Parameters:
    ///     - group: IP address of group to join.
    ///     - index: index of the interface through which multicast messages will be received;
    ///       if 0, default interface will be used.
    public func joinToMulticast(_ group: in_addr, interfaceIndex index: Int32) throws {
        assert(group.isMulticast)
        try joinToMulticast(
            sockaddr_storage(sockaddr_in(group, port: 0)),
            interfaceIndex: index
        )
    }
    
    /// Join to IPv6 multicast group.
    /// - Parameters:
    ///     - group: IPv6 address of group to join.
    ///     - index: index of the interface through which multicast messages will be received;
    ///       if 0, default interface will be used.
    public func joinToMulticast(_ group: in6_addr, interfaceIndex index: Int32) throws {
        assert(group.isMulticast)
        try joinToMulticast(
            sockaddr_storage(sockaddr_in6(group, port: 0)),
            interfaceIndex: index
        )
    }
    
    private func joinToMulticast(
        _ ss: sockaddr_storage,
        interfaceIndex index: Int32 = 0
    ) throws {
        assert(ss.ss_family == AF_INET || ss.ss_family == AF_INET6)
        let level = ss.ss_family == AF_INET6 ? IPPROTO_IPV6 : IPPROTO_IP
        var req = group_req(gr_interface: UInt32(index), gr_group: ss)
        try bsd(
            setsockopt(
                self.handle,
                level,
                MCAST_JOIN_GROUP,
                &req,
                socklen_t(MemoryLayout<group_req>.size)
            )
        )
    }
}
