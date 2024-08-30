section .data
    listeningmsg: db "[*] Waiting for requests", 0x0a, 0x00
    listenfailed: db "[!] Listening failed, port already in-use?", 0x0a, 0x00
    newconnectionmsg: db "[*] New request incoming from: ", 0x00
    requestreceivedmsg: db "[*] Request received: ", 0x00
    connerrormsg: db "[!] Failed accepting new connection", 0x0a, 0x00
    response: db "HTTP/1.0 200 OK", 0x0a, "Content-Length: 27", 0x0a, 0x0a, "<h1>Assembly webserver</h1>", 0x00
    method_get: db "GET"
    newline: db 0x0a, 0x00
    connqueu: int 128

section .bss
    sock resd 1
    srcaddr resb 2
    srcaddrlen resb 1
    conn resd 1
    request resb 128
    methodlength resb 1
    urllength resb 1

section .text
global _start

portnotavail:
    mov rcx, listenfailed
    mov bl, 1 ; stdout
    call write_string
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

    cmp rax, 0
    jnz portnotavail

_listen:
    mov al, 50 ; listen
    ; rdi is normally set, but we've already set it it in _bind
    mov rsi, [connqueu] ; max conn queue of 128 connections
    xor rdx, rdx
    syscall


_listenmsg:
    mov rcx, listeningmsg
    xor rbx, rbx ; clear rbx first before using
    mov bl, 1 ; stdout
    call write_string

_accept:
    mov al, 43 ; accept
    mov rdi, [sock]
    mov rsi, srcaddr
    mov rdx, srcaddrlen
    syscall
    cmp rax, 0
    jle connectionerr
    mov [conn], rax ; store new connection fd to conn

_newconnectionmsg:
    mov rcx, newconnectionmsg
    xor rbx, rbx ; clear rbx first to  remove any bits
    mov bl, 1 ; stdout
    call write_string
    mov rcx, srcaddr
    call write_string
    mov rcx, newline
    call write_string

_readmsg:
    mov rax, 3 ; read
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
    jz _close ; todo: invalid request
    inc rcx ; ++ to next char
    jmp _parsemethodparse
_parsemethoddone:
    mov rbx, rcx
    sub rbx, request
    mov [methodlength], rbx

; after that follows the URL part
_parseurl:
    inc rcx ; jump past space
_parseurlparse:
    cmp [rcx], byte ' '
    jz _parseurldone
    cmp [rcx], byte 0
    jz _close ; todo: invalid request
    inc rcx ; ++ to next char
    jmp _parseurlparse
_parseurldone:
    sub rcx, request
    mov [urllength], rcx

_printrequest:
    xor rbx, rbx ; clear rbx first to remove any bits
    mov bl, 1 ; stdout
    mov rcx, requestreceivedmsg
    call write_string
    mov rcx, request
_printrequestmethod:
    xor rdx, rdx ; clear rdx first
    mov dl, [methodlength]
    call write_lstring
_printrequesturl:
    add rcx, rdx
    mov dl, [urllength]
    sub dl, [methodlength]
    call write_lstring
_printrequestnewline:
    mov rcx, newline
    call write_string

_response:
    mov rbx, [conn] ; fd of current connection
    mov rcx, response
    call write_string

_close:
    mov al, 3 ; close
    mov rdi, [conn]
    syscall

jmp _exit