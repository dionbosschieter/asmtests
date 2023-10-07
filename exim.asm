section .data
    fd:       dq 0
    fdfile:   dq 0
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
        at sin_addr ,    db 0, 0, 0, 0
        at sin_padding , db 0,0,0,0,0,0,0,0
    iend

    ipstring:  db "37.97.128.3", 0xa, 0xd,
    filename: db "ips.txt", 0x0

section .bss
    input resd 1024
    response resd 1

section .text
global _start

_start:

_openfile:
    mov rax, 5 ; open
    mov rbx, filename ; file to open
    mov rcx, 2 ; read/write
    int 0x80 ; syscall
    mov [fdfile], rax ; save file descriptor

_readfile:
    mov rax, 3 ; read
    mov rbx, [fdfile] ; stdin
    mov rcx, input
    mov rdx, 1024
    int 0x80 ; syscall

    cmp rax, 0 ; reached eof yet
    jz _exit

    mov r13, input ; reset offset in input buffer to beginning of buffer

_startreadip:
    mov rcx, r13      ; point rcx to current offset in input buffer
    xor rdx, rdx      ; zero output char registry
    mov r8, 0         ; count for every pair, we start at 0

_readip:
    mov bl, [rcx]   ; load char from buffer into rbx, we use bl here
                    ; because we don't want to load more than the current
                    ; 8 bits of the char
    cmp rbx, '.'    ; if this is a '.' we reached the end of the integer
    jz _ereadip     ; then we are finished for this cycle
    cmp rbx, 0xa    ; we are done, end of string
    jz _ereadip     ; we are finished
    cmp rbx, 0x0    ; end of buffer
    jz _readfile    ; try to read more

    sub rbx, '0'   ; convert from ascii to dec

    cmp rdx, 0     ; we check if we already stored a number in rdx
    jz _currzero   ; we don't have to do any multiplication

    mov rax, 10    ; multiply current number by 10
    mul rdx        ; multiply by 10
    mov rdx, rax   ; store result in rdx again
    add rdx, rbx   ; add (+) the new number to the multiplied number
    jmp _nextchar

_ereadip:
    inc r8
    cmp r8, 4      ; end of ip
    cmovz r12, rdx
    jge _storip
    cmp r8, 3
    cmovz r11, rdx
    cmp r8, 2
    cmovz r10, rdx
    cmp r8, 1
    cmovz r9, rdx

    ; start next cycle of ascii -> dec
    xor rdx, rdx  ; reset output register rdx
    jmp _nextchar ; start with next cycle

_currzero:
    mov rdx, rbx

_nextchar:
    inc rcx        ; increment to next char
    jmp _readip    ; read next char

_storip:
    inc rcx      ; increment to next char, skip newline
    mov r13, rcx ; save current pointer of buffer for later use
    
    mov rax, r12 ; we start with the last digit, because it is in reverse order
    shl rax, 8
    or rax, r11
    shl rax, 8
    or rax, r10
    shl rax, 8
    or rax, r9

    mov [addr + sin_addr], rax ; stor ip in struct

_socket:
    mov rbx, 2 ; AF_INET
    mov rcx, 1 ; SOCK_STREAM
    mov rdx, 6 ; IPPROTO_TCP
    mov rax, 359; sys_socket
    int 0x80 ; syscall
    cmp rax,-1
    jz  _exit
    mov [fd], rax ; save file descriptor

_connect:
    mov rax, 362
    mov rbx, [fd]
    mov rcx, addr
    mov rdx, 0x10
    ; call connect
    int 0x80

_readsocket:
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

    jmp _startreadip

_exit:
    mov rax, 1
    mov rbx, 0
    int 0x80
