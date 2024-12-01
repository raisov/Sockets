//  IPProtocol.h
//  Sockets

#ifndef IPProtocol_h
#define IPProtocol_h

#include <netinet/in.h>

typedef enum __attribute__((enum_extensibility(open))) : int32_t {
    tcp = IPPROTO_TCP,
    udp = IPPROTO_UDP,
    icmp = IPPROTO_ICMP,
    icmpv6 = IPPROTO_ICMPV6,
} IPProtocol;

#endif /* IPProtocol_h */
