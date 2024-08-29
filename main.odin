package main

import "core:fmt"
import "core:net"

main :: proc() {
    using net
    endpoint := par("127.0.0.1:4040")
    sock, err := create_socket(Address_Family.IP4,Socket_Protocol.TCP)
    bind(sock, parse_hostname_or_endpoint("12"))
    if err != nil {
        fmt.print("Failed to create socket")
    }

}