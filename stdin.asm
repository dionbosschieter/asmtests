section .bss
    input resd 1

section .text
global _start

_start:
    mov rax, 3 ; read
    mov rbx, 0 ; stdin
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
