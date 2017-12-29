section .data
    string: db "Assembly", 0x0a
    len:    equ $-string

section .text
global _start

; rcx = (char *)
; rdx = size_t len
_print:
    mov rax, 4
    mov rbx, 1
    mov rcx, string
    mov rdx, len
    int 0x80
    ret
_loop:
    push rax ; save parm to stack
    call _print
    nop
    pop rax ; take num from stack
    dec rax
    cmp rax,0
    jg _loop
    ret
_start:
    mov rax, 5 ; set loop count
    call _loop
    mov rax, 1
    mov rbx, 0
    int 0x80
