package server

import "core:strings"
import "core:os"
import "core:fmt"
import "core:net"

prepare_data_from_server :: proc (file_to_deliver : string) -> ([]u8, response_type){    
    path : strings.Builder
    defer strings.builder_destroy(&path)
    strings.write_string(&path, WEB_ROOT)
    strings.write_string(&path, file_to_deliver)
    // Is this a security issue? -probably
    data, succ := os.read_entire_file_from_filename(strings.to_string(path))
    wanted_response_type := figure_out_response_type(file_to_deliver)
    return data, wanted_response_type
}


figure_out_response_type :: proc(file_returned : string) -> response_type {
        if strings.ends_with(file_returned,".html"){
            return response_type.HTML
        }
        else if strings.ends_with(file_returned, ".json") {
            return response_type.JSON
        }
        else if strings.ends_with(file_returned, ".css") {
            return response_type.CSS
        }
        else if strings.ends_with(file_returned, ".js") {
            return response_type.JAVASCRIPT
        }
        else if strings.ends_with(file_returned, ".md") {
            return response_type.MARKDOWN
        }
        else if strings.ends_with(file_returned, ".xml") {
            return response_type.XML
        }
        else if strings.ends_with(file_returned, ".png") {
            return response_type.PNG
        }
        else if strings.ends_with(file_returned, ".jpeg") || strings.ends_with(file_returned, ".jpg") {
            return response_type.JPEG
        }
        else if strings.ends_with(file_returned, ".bin") {
            return response_type.BINARY
        }
        else if strings.ends_with(file_returned, ".ogg") {
            return response_type.OGG
        }
        else{
            return nil
        }
}

response_text :: proc(number : int) ->  (text : string) {
    switch number {
        case 200:
            text = " OK"
        case 201:
            text = " Created"
        case 202:
            text = " Accepted"
        case 204:
            text = " No Content"
        case 301:
            text = " Moved Permanently"
        case 302:
            text = " Found"
        case 304:
            text = " Not Modified"
        case 400:
            text = " Bad Request"
        case 401:
            text = " Unauthorized"
        case 403:
            text = " Forbidden"
        case 404:
            text = " Not Found"
        case 500:
            text = " Internal Server Error"
        case 502:
            text = " Bad Gateway"
        case 503:
            text = " Service Unavailable"
        case:
            text = " Unknown Status"
    }
    return
}


content_type_text :: proc(type : response_type) -> (text : string){
    switch type {
        case response_type.OGG:
            text = "audio/ogg"
        case response_type.HTML:
            text = "text/html"
        case response_type.JSON:
            text = "application/json"
        case response_type.XML:
            text = "text/xml"
        case response_type.PNG:
            text = "image/png"
        case response_type.JPEG:
            text = "image/jpeg"
        case response_type.BINARY:
            text = "application/octet-stream"
        case response_type.CSS:
            text = "text/css"
        case response_type.JAVASCRIPT:
            text = "text/javascript"
        case response_type.MARKDOWN:
            text = "text/markdown"
        case response_type.WHOLE_REQUEST:
            text = ""
        case response_type.PLAIN:
            fallthrough
        case:
            text = "text/plain"
    }
    return
}

generate_response :: proc(code : int = 200, response_type_wanted : response_type = nil, data : []u8 = nil) -> [dynamic]u8 {
    text : strings.Builder
    type := content_type_text(response_type_wanted)
    reason_phrase := response_text(code)
    
    strings.write_string(&text, "HTTP/1 ")
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

get_data_from_proxy :: proc(endpoint : net.Endpoint, request : ^HTTP_request) -> ([]u8, response_type){
    // Make the messge
    datastring : strings.Builder
    defer strings.builder_destroy(&datastring
    )
    strings.write_string(&datastring, request.request_type)
    strings.write_rune(&datastring, ' ')
    strings.write_string(&datastring, request.route)
    strings.write_rune(&datastring ,' ')
    strings.write_string(&datastring, "HTTP/1\r\n")
    // Now we add headers
    for header in request.headers{
        strings.write_string(&datastring,header)
        strings.write_rune(&datastring,':')
        strings.write_string(&datastring,request.headers[header])
        strings.write_string(&datastring,"\r\n")
    }
    strings.write_string(&datastring,"\r\n")
    strings.write_string(&datastring, request.body)

    next_server, dial_error := net.dial_tcp_from_endpoint(endpoint)
    if dial_error != nil do return nil,nil
    
    return_data := make([]u8,BUFFER_SIZE)

    bytes_written,send_error := net.send_tcp(next_server,datastring.buf[:])
    if send_error != nil do return nil,nil

    bytes_recieved, recieve_error := net.recv_tcp(next_server,return_data[:])
    if recieve_error != nil do return nil,nil

    return return_data,response_type.WHOLE_REQUEST
}


generate_response_data :: proc(request : ^HTTP_request, routes : ^map[string]string) -> ([]u8, response_type){
    if !(request.route in routes){
        return nil, nil
    }
    fmt.println("Here 1")
    data : []u8
    wanted_response_type : response_type
    thing_routed := routes[request.route]

    endpoint, ok := net.parse_endpoint(thing_routed)

    if ok do data, wanted_response_type = get_data_from_proxy(endpoint, request)
    else do data, wanted_response_type = prepare_data_from_server(thing_routed)
    fmt.println("Here 2")
    if data == nil || wanted_response_type == nil do return nil,nil
    
    return data,wanted_response_type
}