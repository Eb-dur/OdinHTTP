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
    reason_phrase := ""
    switch code {
    case 200:
        reason_phrase = " OK"
    case 201:
        reason_phrase = " Created"
    case 202:
        reason_phrase = " Accepted"
    case 204:
        reason_phrase = " No Content"
    case 301:
        reason_phrase = " Moved Permanently"
    case 302:
        reason_phrase = " Found"
    case 304:
        reason_phrase = " Not Modified"
    case 400:
        reason_phrase = " Bad Request"
    case 401:
        reason_phrase = " Unauthorized"
    case 403:
        reason_phrase = " Forbidden"
    case 404:
        reason_phrase = " Not Found"
    case 500:
        reason_phrase = " Internal Server Error"
    case 502:
        reason_phrase = " Bad Gateway"
    case 503:
        reason_phrase = " Service Unavailable"
    case:
        reason_phrase = " Unknown Status"
    }

    strings.write_string(&text, "HTTP/1.1 ")
    strings.write_int(&text, code)
    strings.write_string(&text,reason_phrase)
    strings.write_string(&text, "\r\n")

    //Here we do content type
    
    strings.write_string(&text, "Content-Type: ")
    switch return_type_wanted {
    case return_type.OGG:
        strings.write_string(&text, "audio/ogg")
    case return_type.HTML:
        strings.write_string(&text, "text/html")
    case return_type.JSON:
        strings.write_string(&text, "application/json")
    case return_type.XML:
        strings.write_string(&text, "text/xml")
    case return_type.PNG:
        strings.write_string(&text, "image/png")
    case return_type.JPEG:
        strings.write_string(&text, "image/jpeg")
    case return_type.BINARY:
        strings.write_string(&text, "application/octet-stream")
    case return_type.CSS:
        strings.write_string(&text, "text/css")
    case return_type.JAVASCRIPT:
        strings.write_string(&text, "text/javascript")
    case return_type.MARKDOWN:
        strings.write_string(&text, "text/markdown")
    case return_type.PLAIN:
        fallthrough
    case:
        strings.write_string(&text, "text/plain")
}
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