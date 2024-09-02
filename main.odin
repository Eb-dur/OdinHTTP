package server

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
    PLAIN,
    HTML,
    JSON,
    CSS,
    JAVASCRIPT,
    MARKDOWN,
    XML,
    PNG,
    JPEG,
    BINARY,
    OGG,
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

generate_response :: proc(code : int = 200, return_type_wanted : return_type = nil, data : []u8 = nil) -> [dynamic]u8 {
    text : strings.Builder
    response : []u8
    reason_phrase := http_response_text(code)
    
    strings.write_string(&text, "HTTP/1.1 ")
    strings.write_int(&text, code)
    strings.write_string(&text,reason_phrase)
    strings.write_string(&text, "\r\n")

    //Here we do content type
    strings.write_string(&text, "Content-Type: ")
    type := http_content_type_text(return_type_wanted)
    strings.write_string(&text, type)
    strings.write_string(&text, "\r\n")

   //Here we do len
   strings.write_string(&text, "Content-Lenght: ")
   strings.write_int(&text, len(data) if data != nil else 0)
   strings.write_string(&text, "\r\n")
   strings.write_string(&text, "\r\n")

   //Here we do data

   strings.write_bytes(&text, data)

   return text.buf

}


generate_response_data :: proc(route : string, routes,^map[string]string) -> '[]u8{
    
}

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
            if DEBUG do fmt.println("Failed to accept connection")
            continue
        }
        if DEBUG do fmt.println("Accepted connection from ", client_endpoint)
        bytes_read : int
        bytes_read ,_  = recv_tcp(client_sock, buffer[:])
        parsed, _ := read_request(buffer[:bytes_read])
        if DEBUG do fmt.println("Request:", parsed.request_type,parsed.route, parsed.headers, parsed.body)
        response := generate_response()
        written, _ := send_tcp(client_sock, response[:])
        if DEBUG do fmt.println("response sent, wrote", written, "bytes")
        delete(response)
        close(client_sock)
    }


}