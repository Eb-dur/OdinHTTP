package main

import "core:fmt"
import "core:net"
import "core:strings"

IP :: "127.0.0.1:4040"
request_type :: enum {
    GET,
    POST,
    PUT,
}

HTTP_request :: struct {
    request_type : request_type,
    route : string,
    headers : map[string]string,
    body : map[string]string, // May be needed
}

read_request :: proc(buffer : []byte) -> (^HTTP_request, bool) {
    fmt.println("This request was recieved ", string(buffer))
    request : ^HTTP_request
    workstring : string

    request = new(HTTP_request)
    request_string := string(buffer)

    split_request, err := strings.split(request_string,"\r\n")
    if err != nil{
        fmt.println("Error in memory assignment")
    }
    // Get type
    workstring = split_request[0]
    request_split, err2 := strings.split(workstring, " ")
    if err2 != nil{
        fmt.println("Error in memory assignment")
    }
    
    fmt.println("request split 0: ", request_split[0])
    switch request_split[0]{
        case "GET":
            request.request_type = request_type.GET
        case "POST":
            request.request_type = request_type.POST
        case "PUT":
            request.request_type = request_type.PUT
    }
    // Get route
    request.route = strings.clone(request_split[1])    
    return request, true
}

main :: proc() {
    using net
    endpoint, ok := parse_endpoint(IP)

    sock, err:= listen_tcp(endpoint,10)
    if err != nil {
        fmt.println("Failed to create socket")
        return
    }
    fmt.println("Socket is up and running on", IP, "waiting for connections")
    for {
        client_sock, client_endpoint, errc := accept_tcp(sock)
        if errc != nil{
            fmt.println("Failed to accept connection")
            continue
        }
        fmt.println("Accepted connection from ", client_endpoint)
        buffer := make([]byte, 1024)
        bytes_read : int
        bytes_read ,_  = recv_tcp(client_sock, buffer)
        parsed, _ := read_request(buffer[:bytes_read])
        fmt.println("Request:", parsed.request_type,parsed.route,)
        response := transmute([]u8)string("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\n\r\nHello, world!")
        written, _ := send_tcp(client_sock, response)
        fmt.println("response sent, wrote", written, "bytes")
        close(client_sock)
        delete(response)
        delete(buffer)
    }

}