//  SocketType.h
//  Sockets

#ifndef SocketType_h
#define SocketType_h

#include <sys/sockio.h>

typedef enum __attribute__((enum_extensibility(open))) : int32_t {
    stream = SOCK_STREAM,
    datagram = SOCK_DGRAM,
    raw = SOCK_RAW,
    seqpacket = SOCK_SEQPACKET,
} SocketType;

#endif /* SocketType_h */
