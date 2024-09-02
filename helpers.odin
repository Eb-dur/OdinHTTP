package server

http_response_text :: proc(number : int) ->  (text : string) {
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


http_content_type_text :: proc(type : return_type) -> (text : string){
    switch type {
        case return_type.OGG:
            text = "audio/ogg"
        case return_type.HTML:
            text = "text/html"
        case return_type.JSON:
            text = "application/json"
        case return_type.XML:
            text = "text/xml"
        case return_type.PNG:
            text = "image/png"
        case return_type.JPEG:
            text = "image/jpeg"
        case return_type.BINARY:
            text = "application/octet-stream"
        case return_type.CSS:
            text = "text/css"
        case return_type.JAVASCRIPT:
            text = "text/javascript"
        case return_type.MARKDOWN:
            text = "text/markdown"
        case return_type.PLAIN:
            fallthrough
        case:
            text = "text/plain"
    }
    return
}