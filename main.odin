package main

import "core:fmt"
import "core:net"
import "core:strings"
import "core:encoding/json"
import "core:os"

DEBUG :: false
IP :: "127.0.0.1:4040"
request_type :: enum {
    GET,
    POST,
    PUT,
}

return_type :: enum {
    TEXTPLAIN,
    HTML,
}

HTTP_request :: struct {
    request_type : request_type,
    route : string,
    headers : map[string]string,
    body : string, // May be needed
}

parse_routes :: proc(routing_map : ^map[string]string) {
    file_content, success := os.read_entire_file_from_filename("routings.json")

    if !success {
        fmt.print("Failed to read routings.json")
        return
    }

    if !(json.unmarshal(file_content, routing_map) == nil){
        fmt.print("Failed to unmarshal JSON")
    }
}

read_request :: proc(buffer : []byte) -> (^HTTP_request, bool) {
    if DEBUG do fmt.println("This request was recieved ", string(buffer))

    request : ^HTTP_request
    request = new(HTTP_request)
    request_string := string(buffer)

    split_request, err := strings.split(request_string,"\r\n")
    defer delete(split_request)
    if err != nil{
        fmt.println("Error in memory assignment")
    }
    // Get type
    http_formalia := split_request[0]
    http_formalia_split, err2 := strings.split(http_formalia, " ")
    defer delete(http_formalia_split)
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

  
    // Get headers
    for header_index : int = 3 ; split_request[header_index] == ""; header_index += 1 {
        split_string, err := strings.split(split_request[header_index], ":")
        if err == nil do request.headers[split_string[0]] = split_string[1]
        delete(split_string)
    }
    // Get body
    request.body = strings.clone(split_request[len(split_request) - 1])

    return request, true
}

generate_response :: proc(code : int = 200, ) -> []u8

main :: proc() {
    using net
    endpoint, ok := parse_endpoint(IP)
    routings := make(map[string]string)
    defer delete(routings)
    parse_routes(&routings)

    if DEBUG do fmt.println(routings)

    sock, err:= listen_tcp(endpoint,10)
    if err != nil {
        fmt.println("Failed to create socket")
        return
    }


    fmt.println("Socket is up and running on", IP, "waiting for connections")
    buffer : [1024]byte
    for {
        client_sock, client_endpoint, errc := accept_tcp(sock)
        if errc != nil{
            fmt.println("Failed to accept connection")
            continue
        }
        fmt.println("Accepted connection from ", client_endpoint)
        bytes_read : int
        bytes_read ,_  = recv_tcp(client_sock, buffer[:])
        parsed, _ := read_request(buffer[:bytes_read])
        fmt.println("Request:", parsed.request_type,parsed.route, parsed.headers, parsed.body)
        response := transmute([]u8)string("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\n\r\nHello, world!")
        written, _ := send_tcp(client_sock, response)
        fmt.println("response sent, wrote", written, "bytes")
        close(client_sock)
    }


}