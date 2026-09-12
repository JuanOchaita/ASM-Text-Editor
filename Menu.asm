.MODEL SMALL
.STACK 100h

.CODE

main PROC
    mov ax,@data
    mov ds,ax

    mov ax,0013h
    int 10h

    mov dx,03C8h
    xor al,al
    out dx,al

    mov dx,03C9h
    mov al,24
    out dx,al
    mov al,20
    out dx,al
    mov al,28
    out dx,al

    mov ax,0A000h
    mov es,ax
    xor di,di
    xor al,al
    mov cx,64000
    cld
    rep stosb

    xor ah,ah
    int 16h

    mov ax,0003h
    int 10h

    mov ax,4C00h
    int 21h

main ENDP
END main