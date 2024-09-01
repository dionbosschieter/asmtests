section .data
    listeningmsg: db "[*] Waiting for requests", 0x0a, 0x00
    listenfailed: db "[!] Listening failed, port already in-use?", 0x0a, 0x00
    newconnectionmsg: db "[*] New request incoming from: ", 0x00
    requestreceivedmsg: db "[*] Request received: ", 0x00
    connerrormsg: db "[!] Failed accepting new connection", 0x0a, 0x00
    response: db "HTTP/1.0 200 OK", 0x0a, "Content-Type: text/html", 0x0a, "Content-Length: 27", 0x0a, 0x0a, "<h1>Assembly webserver</h1>", 0x00
    response404: db "HTTP/1.0 404 Not Found", 0x0a, "Content-Type: text/html", 0x0a, "Content-Length: 15", 0x0a, 0x0a, "<h1>404 :(</h1>", 0x00
    response400: db "HTTP/1.0 400 Bad Request", 0x0a, 0x00
    method_get: db "GET"
    newline: db 0x0a, 0x00

section .bss
    sock resd 1
    srcaddr resb 16
    srcaddrlen resd 1
    conn resd 1
    request resb 128
    methodlength resd 1
    urllength resd 1
    urlpointer resd 1

section .text
global _start

portnotavail:
    mov rcx, listenfailed
    call log_string
    jmp _exit

connectionerr:
    mov rcx, connerrormsg
    mov bl, 1 ; stdout
    call write_string
    jmp _exit

write_string:
    mov rax, rcx
    call strlen
    jmp write_lstring
write_lstring: ; expects rdx to be set with strlen to print
    xor rax, rax
    mov al, 4 ; write
    int 0x80 ; syscall
    ret

log_string:
    xor rbx, rbx ; clear rbx first before using
    mov bl, 1 ; stdout
    call write_string
    ret

strlen:
    xor rdx, rdx ; we count in rdx because we are lazy, saves a store, we need it for write in rdx
    jmp _strlen
_strlen:
    cmp [rax], byte 0
    jz _strlen_out
    inc rax
    inc rdx ; we count in rdx because we are lazy, saves a store, we need it for write in rdx
    jmp _strlen
_strlen_out:
    ret

badrequest:
    mov rbx, [conn] ; fd of current connection
    mov rcx, response400
    call write_string
    jmp _close

_exit:
    mov rax, 1
    mov rbx, 0
    int 0x80

_start:
_socket:
    ; todo, set reuse
    xor rax, rax ; clear rax
    xor rbx, rbx ; clear rbx
    xor rcx, rcx ; clear rcx
    xor rdx, rdx ; clear rdx
    ; we use the bl,cl,dl registers instead of rbx rcx rdx registers because
    ; they result in extra 0 bytes in the shell code
    mov bl, 2 ; AF_INET
    mov cl, 1 ; SOCK_STREAM
    mov dl, 6 ; IPPROTO_TCP
    mov ax, 359; sys_socket
    int 0x80 ; syscall
    mov [sock], rax ; save file descriptor to sock variable, we need it for bind, listen and accept

_bind:
    mov rbx, 0x00000000901f0002 ; 0.0.0.0:8080 AF_INET
    push rbx ; use rbx here, because we overwrite it afterwards, so we save a xor to clear it

    mov al, 49 ; bind
    mov rdi, [sock] ; fd of socket
    mov rsi, rsp ; point to struct on the stack
    mov dl, 0x10 ; statically define length of struct on the stack, always the same length
    syscall

    cmp al, 0
    jnz portnotavail

_listen:
    mov al, 50 ; listen
    ; rdi is normally set, but we've already set it it in _bind
    xor rsi, rsi
    mov rsi, 128 ; max conn queue of 128 connections
    xor rdx, rdx
    syscall
    mov rcx, listeningmsg
    call log_string

_accept:
    mov al, 43 ; accept
    mov rdi, [sock]
    mov rsi, srcaddr
    mov rdx, srcaddrlen
    syscall
    cmp al, 0
    jle connectionerr
    mov [conn], rax ; store new connection fd to conn

_newconnectionmsg:
    mov rcx, newconnectionmsg
    call log_string
    mov rcx, srcaddr
    xor rdx, rdx ; clear rdx first
    mov dl, [srcaddrlen] ; srcaddrlen amount of bytes that srcaddr has into dl
    call write_lstring
    mov rcx, newline
    call write_string

_readmsg:
    xor rax, rax
    mov al, 3 ; read
    mov rbx, [conn] ; fd of current connection
    mov rcx, request
    mov rdx, 128
    int 0x80 ; syscall

; method is always the beginning of the request
_parsemethod:
    mov rcx, request
_parsemethodparse:
    cmp [rcx], byte ' '
    jz _parsemethoddone
    cmp [rcx], byte 0
    jz badrequest
    inc rcx ; ++ to next char
    jmp _parsemethodparse
_parsemethoddone:
    mov rbx, rcx
    sub rbx, request ; end-start = length
    mov [methodlength], bl

; after that follows the URL part
_parseurl:
    inc rcx ; jump past space
    mov [urlpointer], rcx ; record start of url part
_parseurlparse:
    cmp [rcx], byte ' '
    jz _parseurldone
    cmp [rcx], byte 0
    jz badrequest
    inc rcx ; ++ to next char
    jmp _parseurlparse
_parseurldone:
    sub rcx, [urlpointer] ; end-start = length
    mov [urllength], cl

_printrequest:
    mov rcx, requestreceivedmsg
    call log_string
_printrequestmethod:
    xor rdx, rdx ; clear rdx first
    mov rcx, request
    mov dl, [methodlength]
    call write_lstring
_printrequesturl:
    mov rcx, [urlpointer]
    mov dl, [urllength]
    call write_lstring
    mov rcx, newline
    call write_string

; if *urlpointer == '/' respond with response
; todo create strcmp function
_checkurl:
    mov rcx, [urlpointer]
    cmp [rcx], byte '/'
    jnz _404
    cmp [urllength], byte 1 ; strlen is equal to what we expect
    jnz _404

_response:
    mov rbx, [conn] ; fd of current connection
    mov rcx, response
    call write_string
    jmp _close

_404:
    mov rbx, [conn]
    mov rcx, response404
    call write_string
    jmp _close

_close:
    mov al, 3 ; close
    mov rdi, [conn]
    syscall

; loop back
mov [request], byte 0 ; clean request buffer
jmp _accept

_bye:
    mov al, 3 ; close
    mov rdi, [sock]
    syscall
    jmp _exit