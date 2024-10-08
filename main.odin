package server

import "core:os"
import "core:fmt"
import "core:net"
import "core:mem"
import "core:c/libc"
import "core:thread"
import "core:strings"
import "core:encoding/json"
import "core:path/filepath"
import "base:runtime"



WEB_ROOT :: "./www/"

DEBUG :: true
IP :: "127.0.0.1:4040"
BUFFER_SIZE :: 1024
/*
request_type :: enum {
    GET,
    POST,
    PUT,
}
*/

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
    WHOLE_REQUEST
}

HTTP_request :: struct {
    request_type : string,
    route : string,
    headers : map[string]string,
    body : string,
}

socket_and_map_bundle :: struct{
    socket : net.TCP_Socket,
    routings : ^map[string]string
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

        if route in routing_map^{

            fmt.println("Due to files existing this route is overritten:", route)
        
        }

        for key in routing_map{
            
            _ , is_ip := net.parse_endpoint(routing_map[key])
    
            if is_ip && strings.has_prefix(route, key){

                fmt.println(key, "Will redirect traffic from server and will therefore not serve", route)

            }
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
    
    request.request_type = http_formalia_split[0]
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


worker :: proc(data : rawptr){
    bundle := cast(^socket_and_map_bundle)data
    defer free(bundle)

    client_sock := bundle.socket
    defer net.close(client_sock)
    
    routings := bundle.routings 
    did_i_fail := false
    buffer : [BUFFER_SIZE]byte

    data : []u8
    defer delete(data)

    response_type_wanted : response_type
    
    bytes_read : int
    recieve_error : net.Network_Error
    bytes_read ,recieve_error = net.recv_tcp(client_sock, buffer[:])
    
    if recieve_error != nil {
    
        if DEBUG do fmt.println("Could not recieve tcp data, network error")
        return
    
    }
    
    if DEBUG do fmt.println("Request:", buffer)
    
    parsed, succ := read_request(buffer[:bytes_read])
    defer free(parsed)
    
    if !succ{
    
        if DEBUG do fmt.println("Could not read request, error")
        did_i_fail = true
    
    }
    
    if !did_i_fail{
    
        data, response_type_wanted = generate_response_data(parsed, routings)
        fmt.println("I am returning this type ", response_type_wanted)
        if data == nil || response_type_wanted == nil do did_i_fail = true
    
    }

    response : [dynamic]u8
    defer delete(response)
    
    if did_i_fail{
    
        response = generate_response(400)
    
    }
    else if response_type_wanted != response_type.WHOLE_REQUEST{

        response = generate_response(200, response_type_wanted, data)
    
    }
    else{
        append(&response, ..data[:])
        //delete(data)
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
    threads := make([dynamic]^thread.Thread)
    
    //Server is upp and will now listen

    for {
        
        client_sock, client_endpoint, errc := net.accept_tcp(sock)
        
        if DEBUG do fmt.println("Accepted connection from ", client_endpoint)
        
        if errc != nil{
        
            if DEBUG do fmt.println("Failed to accept connection")
            return
        
        }
        else{

            if DEBUG do fmt.println("Craeting new thread and responding")
            
            bundle := new(socket_and_map_bundle)
            bundle.socket = client_sock
            bundle.routings = &routings
            thread.create_and_start_with_data(bundle,worker,context, thread.Thread_Priority.Normal,true)
        
        }
    }
}
