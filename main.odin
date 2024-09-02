package server

import "core:fmt"
import "core:net"
import "core:strings"
import "core:encoding/json"
import "core:os"
import "core:path/filepath"


WEB_ROOT :: "./www/"

DEBUG :: true
IP :: "127.0.0.1:4040"
request_type :: enum {
    GET,
    POST,
    PUT,
}

response_type :: enum {
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
    body : string,
}

Walk_Proc :: proc(info: os.File_Info, in_err: os.Errno, user_data: rawptr) -> (err: os.Errno, skip_dir: bool) {
    if in_err != 0 {
        fmt.println("Error:", in_err)
        return in_err, false
    }

    if !info.is_dir{
        routing_map := cast(^map[string]string)(user_data)
        current_dir := os.get_current_directory()
        defer delete(current_dir)
        slice_of_file_route := info.fullpath[len(current_dir) + 4:]
        route, alloc := filepath.to_slash(slice_of_file_route)
        if !alloc{
            route = strings.clone(route)
        }

        if route in routing_map^{
            fmt.println("Due to files existing this route is overritten:", route)
        }

        (routing_map^)[route] = strings.clone(route)
    }
    return os.ERROR_NONE, false
}


parse_routes :: proc(routing_map : ^map[string]string) {
    file_content, success := os.read_entire_file_from_filename("routings.json")

    if !success {
        fmt.print("Failed to read routings.json")
        return
    }

    if !(json.unmarshal(file_content, routing_map) == nil){
        fmt.print("Failed to unmarshal JSON")
        return
    }

    filepath.walk(WEB_ROOT,Walk_Proc, rawptr(routing_map))
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

generate_response :: proc(code : int = 200, response_type_wanted : response_type = nil, data : []u8 = nil) -> [dynamic]u8 {
    text : strings.Builder
    type := http_content_type_text(response_type_wanted)
    reason_phrase := http_response_text(code)
    
    strings.write_string(&text, "HTTP/1.1 ")
    strings.write_int(&text, code)
    strings.write_string(&text,reason_phrase)
    strings.write_string(&text, "\r\n")

    //Here we do content type
    strings.write_string(&text, "Content-Type: ")
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


generate_response_data :: proc(route : string, routes : ^map[string]string) -> ([]u8, response_type){
    if !(route in routes){
        return nil, nil
    }
    file_to_deliver := routes[route]
    
    path : strings.Builder
    defer strings.builder_destroy(&path)

    strings.write_string(&path, WEB_ROOT)
    strings.write_string(&path, file_to_deliver)
    // Is this a security issue? -probably
    data, succ := os.read_entire_file_from_filename(strings.to_string(path))
    wanted_response_type := http_figure_out_response_type(file_to_deliver)

    if !succ || wanted_response_type == nil do return nil,nil
    
    return data,wanted_response_type
}

worker :: proc(socket : net.TCP_Socket, routings : ^map[string]string){
    did_i_fail := false
    buffer : [1024]byte

    data : []u8
    defer delete(data)

    response_type_wanted : response_type

    client_sock, client_endpoint, errc := net.accept_tcp(socket)
    defer net.close(client_sock)

    if errc != nil{
        if DEBUG do fmt.println("Failed to accept connection")
        return
    }

    if DEBUG do fmt.println("Accepted connection from ", client_endpoint)
    
    bytes_read : int
    recieve_error : net.Network_Error
    bytes_read ,recieve_error = net.recv_tcp(client_sock, buffer[:])
    fmt.println(string(buffer[:bytes_read]))
    if recieve_error != nil {
        if DEBUG do fmt.println("Could not recieve tcp data, network error")
        return
    }
    
    if DEBUG do fmt.println("Request:", buffer)
    parsed, succ := read_request(buffer[:bytes_read])
    
    if !succ{
        if DEBUG do fmt.println("Could not read request, error")
        did_i_fail = true
    }
    
    if !did_i_fail{
        data, response_type_wanted = generate_response_data(parsed.route, routings)
        fmt.println("I am returning this type ", response_type_wanted)
        if data == nil || response_type_wanted == nil do did_i_fail = true
    }
    response : [dynamic]u8
    defer delete(response)
    if did_i_fail{
        response = generate_response(400)
    }
    else{
        response = generate_response(200, response_type_wanted, data)
    }
    written, _ := net.send_tcp(client_sock, response[:])
    if DEBUG do fmt.println("response sent, wrote", written, "bytes")
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
    for {
        worker(sock, &routings)
    }


}