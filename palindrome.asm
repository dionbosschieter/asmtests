section .data
    prompt:     db "name> ", 0x0
    correct:    db " is a palindrome", 0xa, 0xd, 0x0
    incorrect:  db " is not a palindrome", 0xa, 0xd, 0x0

section .bss
    name resd 1

section .text
global _start

write_buffer:
    mov rax, 4 ; write
    mov rbx, 1 ; stdout
    int 0x80 ; syscall
    ret

write_string:
    mov rax, rcx
    call strlen
    call write_buffer
    ret

exit:
    mov rax, 1
    mov rbx, 0
    int 0x80

strlen:
    mov rdx, 0 ; we count in rdx because we are lazy, saves a store, we need it for write in rdx
    jmp _strlen

_strlen:
    cmp [rax], byte 0
    jz _strlen_out
    inc rax
    inc rdx ; we count in rdx because we are lazy, saves a store, we need it for write in rdx
    jmp _strlen

_strlen_out:
    ret

readstdin:
    mov rax, 3 ; read
    mov rbx, 0 ; stdin
    mov rcx, name
    mov rdx, 64
    int 0x80 ; syscall
    ret

; rdx = strlen
; rcx = string
check_palindrome:
    mov rbx, rcx ; copy string to rbx as well
    dec rdx
    add rbx, rdx ; point to end of rbx
    jmp _check_palindrome

_check_palindrome:
    cmp rdx, 0
    jz _check_palindrome_true
    dec rdx ; always decrease char counter

    mov al, [rcx] ; load current char from rcx
    cmp al, [rbx] ; check if loaded char equals reversed string at same index
    jnz _check_palindrome_false

    inc rcx
    dec rbx
    jmp _check_palindrome

_check_palindrome_true:
    mov rcx, correct
    call write_string
    ret

_check_palindrome_false:
    mov rcx, incorrect
    call write_string
    ret

_start:
    mov rcx, prompt
    call write_string

    call readstdin

    ; reprint the name from the name buffer
    ; get strlen of name buffer
    mov rax, name
    call strlen
    ; remove the newline as well, as strlen counts till 0x0
    dec rdx
    mov rcx, name
    call write_buffer

    call check_palindrome

    call exit
