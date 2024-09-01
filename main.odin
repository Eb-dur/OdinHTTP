package main

import "core:fmt"
import "core:net"
import "core:strings"

DEBUG :: false
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
    body : string, // May be needed
}

read_request :: proc(buffer : []byte) -> (^HTTP_request, bool) {
    if DEBUG do fmt.println("This request was recieved ", string(buffer))
    
    request : ^HTTP_request

    request = new(HTTP_request)
    request_string := string(buffer)

    split_request, err := strings.split(request_string,"\r\n")
    if err != nil{
        fmt.println("Error in memory assignment")
    }
    // Get type
    http_formalia := split_request[0]
    http_formalia_split, err2 := strings.split(http_formalia, " ")
    if err2 != nil{
        fmt.println("Error in memory assignment")
    }
    
    switch http_formalia_split[0]{
        case "GET":
            request.request_type = request_type.GET
        case "POST":
            request.request_type = request_type.POST
        case "PUT":
            request.request_type = request_type.PUT
    }
    // Get route
    request.route = strings.clone(http_formalia_split[1])
    // Formalia done
    delete(http_formalia_split)
  
    // Get headers
    for header_index : int = 3 ; split_request[header_index] == ""; header_index += 1 {
        split_string, err := strings.split(split_request[header_index], ":")
        if err == nil do request.headers[split_string[0]] = split_string[1]
        delete(split_string)
    }
    // Get body
    request.body = split_request[len(split_request) - 1]
    delete(split_request)

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
    buffer := make([]byte, 1024)
    for {
        client_sock, client_endpoint, errc := accept_tcp(sock)
        if errc != nil{
            fmt.println("Failed to accept connection")
            continue
        }
        fmt.println("Accepted connection from ", client_endpoint)
        bytes_read : int
        bytes_read ,_  = recv_tcp(client_sock, buffer)
        parsed, _ := read_request(buffer[:bytes_read])
        fmt.println("Request:", parsed.request_type,parsed.route, parsed.headers, parsed.body)
        response := transmute([]u8)string("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\n\r\nHello, world!")
        written, _ := send_tcp(client_sock, response)
        fmt.println("response sent, wrote", written, "bytes")
        close(client_sock)
    }
    delete(buffer)

}