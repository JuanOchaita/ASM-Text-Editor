.MODEL SMALL
.STACK 100h

.DATA

IMAGEN LABEL WORD
KX dw 12
KY dw 19
iposx dw 149
iposy dw 85

imagend db 255,0,0,0,0,0,0,0,0,0,0,0
db 255,255,0,0,0,0,0,0,0,0,0,0
db 255,28,255,0,0,0,0,0,0,0,0,0
db 255,28,15,255,0,0,0,0,0,0,0,0
db 255,28,15,15,255,0,0,0,0,0,0,0
db 255,28,15,15,15,255,0,0,0,0,0,0
db 255,28,15,15,15,15,255,0,0,0,0,0
db 255,28,15,15,15,15,15,255,0,0,0,0
db 255,28,15,15,15,15,15,15,255,0,0,0
db 255,28,15,15,15,15,15,15,15,255,0,0
db 255,28,15,15,15,15,15,15,15,15,255,0
db 255,28,15,15,15,15,15,28,28,28,28,255
db 255,28,15,15,15,15,15,255,255,255,255,0
db 255,28,15,28,255,28,15,255,0,0,0,0
db 255,28,28,255,0,255,28,15,255,0,0,0
db 255,28,255,0,0,255,28,15,255,0,0,0
db 255,255,0,0,0,0,255,28,28,255,0,0
db 0,0,0,0,0,0,255,28,28,255,0,0
db 0,0,0,0,0,0,0,255,255,0,0,0

.CODE
main PROC
    mov ax,@data
    mov ds,ax

    mov ax,0013h
    int 10h

    mov dx,03C8h
    xor al,al
    out dx,al

    ; Color 0 = contorno (202041h)
    mov dx,03C9h
    mov al,8
    out dx,al
    mov al,8
    out dx,al
    mov al,16
    out dx,al

    mov dx,03C8h
    mov al,1
    out dx,al

    ; Color 1 = fondo/relleno morado
    mov dx,03C9h
    mov al,24
    out dx,al
    mov al,20
    out dx,al
    mov al,28
    out dx,al

    ; Rellenar toda la pantalla con el contorno (color 0)
    mov ax,0A000h
    mov es,ax
    xor di,di
    xor al,al
    mov cx,64000
    cld
    rep stosb

    ; Dibujar el rectángulo interior morado (color 1)
    mov di,14*320+4      ; fila 14, columna 4
    mov cx,182           ; filas: 196-14
rellenar_fila:
    push cx
    mov cx,312           ; columnas: 316-4
    mov al,1
    rep stosb
    pop cx
    add di,320-312        ; saltar al inicio de la siguiente fila
    loop rellenar_fila


    mov ax, iposy
    mov bx, 320
    mul bx
    add ax, iposx
    mov di, ax

    lea si, imagend

    mov bx, 320
    sub bx, KX

    mov cx, KY

draw_row:
    push cx
    mov cx, KX

draw_pixel:
    lodsb
    cmp al, 0
    je skip_pixel

    mov es:[di], al

skip_pixel:
    inc di
    loop draw_pixel

    pop cx
    add di, bx
    loop draw_row

    xor ah,ah
    int 16h

    mov ax,0003h
    int 10h

    mov ax,4C00h
    int 21h

main ENDP
END main