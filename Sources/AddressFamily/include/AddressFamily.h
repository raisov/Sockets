//  AddressFamily.h
//  Sockets

#ifndef AddressFamily_h
#define AddressFamily_h

#include <sys/sockio.h>

typedef enum __attribute__((enum_extensibility(open))) : int32_t {
    unix = AF_UNIX,
    inet = AF_INET,
    inet6 = AF_INET6,
    link = AF_LINK
} AddressFamily;

#endif /* AddressFamily_h */
