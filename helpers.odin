package server

import "core:strings"
import "core:os"
import "core:fmt"


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
        case response_type.PLAIN:
            fallthrough
        case:
            text = "text/plain"
    }
    return
}