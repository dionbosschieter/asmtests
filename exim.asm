section .data
    fd:       dq 0
    one:      dq 1

    struc sockaddr
        sin_family  resb 2
        sin_port    resb 2
        sin_addr    resb 4
        sin_padding resb 8
    endstruc

    addr istruc sockaddr
        at sin_family ,  dw 2
        at sin_port ,    db 0x00, 0x19
        at sin_addr ,    db 37, 97, 128, 3 ; 37.97.128.3
        at sin_padding , db 0,0,0,0,0,0,0,0
    iend

section .bss
    response resd 1

section .text
global _start

_start:

_socket:
    mov rbx, 2 ; AF_INET
    mov rcx, 1 ; SOCK_STREAM
    mov rdx, 6 ; IPPROTO_TCP
    mov rax, 359; sys_socket
    int 0x80 ; syscall
    cmp rax,-1
    jz  _exit
    mov [fd], rax ; save file descriptor

setsockopt:
    mov rax, 366
    mov rbx,[fd]
    mov rcx, 0x0001 ; sol_socket
    mov rdx, 0x0002 ; reuseaddr
    mov rsi, one ; true
    mov rdi, 4 ; true
    int 0x80 ; syscall
    cmp rax,-1
    jz  _exit

_connect:
    mov rax, 362
    mov rbx, [fd]
    mov rcx, addr
    mov rdx, 0x10
    ; call connect
    int 0x80

_read:
    mov rax, 3 ; read
    mov rbx, [fd] ; stdin
    mov rcx, response
    mov rdx, 1024 ; 1024 bytes ought to be enough
    int 0x80 ; syscall

_write:
    mov rax, 4 ; write
    mov rbx, 1 ; stdout
    mov rcx, response
    mov rdx, 1024
    int 0x80 ; syscall

_close:
    mov rbx, [fd]
    mov rax, 6 ; close
    int 0x80 ; syscall

_exit:
    mov rax, 1
    mov rbx, 0
    int 0x80
