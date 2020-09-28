section .data
    filename: db "file.txt", 0x0
    fd:       dq 0

section .bss
    input resd 1

section .text
global _start

_start:
    mov rax, 5 ; open
    mov rbx, filename ; file to open
    mov rcx, 2 ; read/write
    int 0x80 ; syscall
    mov [fd], rax ; save file descriptor

    mov rax, 3 ; read
    mov rbx, [fd] ; stdin
    mov rcx, input
    mov rdx, 1024
    int 0x80 ; syscall

    mov rax, 4 ; write
    mov rbx, 1 ; stdout
    mov rcx, input
    mov rdx, 1024
    int 0x80 ; syscall

    mov rax, 1
    mov rbx, 0
    int 0x80
