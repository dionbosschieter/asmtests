section .data
    fd:       dq 0
    fdfile:   dq 0

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

    filename: db "ips.txt", 0x0
    postfix: db " is running exim", 0xa, 0xd, 0x0
    postfixlen: equ $-postfix
    strtomatch: db "Exim", 0x0

section .bss
    input resd 128
    line resd 64
    response resd 1024

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
    mov rdx, 128
    int 0x80 ; syscall

    cmp rax, 0   ; reached eof yet
    jz _exit
    cmp rax, 128 ; if we read less than the buffer, we put a null byte in,
                 ; so the getnextline stops at the right moment,
                 ; because we are reusing a buffer here without zeroing it
    je _resetinputbufferpointer
    mov [input + rax], byte 0 ; put 0 byte at end of buffer, if we don't do this
_resetinputbufferpointer:
    mov r13, input ; reset offset in input buffer to beginning of buffer

_getnextline:
    cmp r14, 0
    jnz _restorelinebuffercounter
    mov rax, 0              ; reset line buffer counter
    mov rbx, 0              ; reset rbx, who knows what is in it
    jmp _readcharforline
_restorelinebuffercounter:
    mov rax, r14
_readcharforline:
    mov bl, [r13]           ; read first character
    cmp bl, 0xa             ; reached newline?
    jnz _processcharforline ; continue
    mov rbx, 0
    mov [line + rax], bl    ; put 0 char at end of string
    inc r13
    jmp _linecomplete
_processcharforline:
    cmp bl, 0x0             ; reached end of input buffer?
    jz _readmorefrominput
    mov [line + rax], rbx   ; stor the character in the line buffer
    inc rax                 ; jump in line buffer to next char position
    inc r13                 ; jump in input buffer to next char position
    cmp rax, 63             ; reached end of buffer?
    jz _linecomplete
    jmp _readcharforline

_readmorefrominput:
    mov r14, rax ; store current location of linebuffer so that we can continue
    jmp _readfile

_linecomplete:
    mov r14, 0    ; we are not in the middle of getting the next line, reset r14
                  ; the getnextline logic depends on this

_startreadip:
    mov rcx, line     ; point rcx to current offset in input buffer
    xor rdx, rdx      ; zero output char registry
    mov r8, 0         ; count for every pair, we start at 0

_readip:
    mov bl, [rcx]   ; load char from buffer into rbx, we use bl here
                    ; because we don't want to load more than the current
                    ; 8 bits of the char
    cmp rbx, '.'    ; if this is a '.' we reached the end of the integer
    jz _ereadip     ; then we are finished for this cycle
    cmp rbx, 0x0    ; we are done, end of string
    jz _ereadip     ; we are finished

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
    jz _exit
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
    mov [response + rax], byte 0 ; reset response buffer

    ; prepare str compare
    mov rcx, response
    mov rdx, strtomatch

_parseresponse:
    mov bl, [rcx]    ; read char from response
    cmp bl, 0x0      ; end of response found
    jz _close        ; go to write section if we are at the end of the buffer
    cmp bl, [rdx]    ; do we find the First letter?
    jnz _nextresponsechar

_comparenextchar:
    inc rcx          ; next char
    inc rdx          ; next char of what to compare with
    cmp [rdx], byte 0
    jz _write ; we are done, we matched all chars
    mov bl, [rcx]    ; read char from response
    cmp bl, 0x0      ; end of response found
    jz _close        ; go to write section if we are at the end of the buffer
    cmp bl, [rdx]    ; do we find the next char from the compare string
    jnz _nextresponsechar
    jmp _comparenextchar
_nextresponsechar:
    mov rdx, strtomatch ; reset str compare pointer to beginning of str to compare with
    inc rcx
    jmp _parseresponse

_write:
    mov rax, 4 ; write
    mov rbx, 1 ; stdout
    mov rcx, line
    mov rdx, 64
    int 0x80 ; syscall

_writenewline:
    mov rax, 4
    mov rbx, 1
    mov rcx, postfix
    mov rdx, postfixlen
    int 0x80

_close:
    mov rbx, [fd]
    mov rax, 6 ; close
    int 0x80 ; syscall

    jmp _getnextline

_exit:
    mov rax, 1
    mov rbx, 0
    int 0x80
