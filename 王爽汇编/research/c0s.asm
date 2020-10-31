assume cs:code,ds:data
data segment
    db 128 dup (0)
data ends

code segment
start:
    mov ax,data
    mov ds,ax
    mov ss,ax
    mov sp,128

    call s

    mov ax,4C00H
    int 21H

s:
code ends
end start