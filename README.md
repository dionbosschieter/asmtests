# asmtests
`nasm -f elf64 test.asm && ld test.o -o test && ./test`

### cat
```
[0] me@mach ~/code/asmtests(master) $ nasm -f elf64 cat.asm && ld cat.o -o cat && strace -f ./cat
execve("./cat", ["./cat"], 0x7fff12ccebb8 /* 69 vars */) = 0
strace: [ Process PID=9248 runs in 32 bit mode. ]
open("file.txt", O_RDWR)                = 3
read(3, "test1337\n", 1024)             = 9
write(1, "test1337\n\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 1024test1337
) = 1024
exit(0)                                 = ?
+++ exited with 0 +++
```
