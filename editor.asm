; Proyecto 1 - Arquitectura y Diseno de Computadoras
; Primera entrega de la pantalla de edicion (x8086 / MASM-TASM)
;
; Implementado en esta parte:
;   - Marco visual de la pantalla de edicion.
;   - Escritura de letras, numeros, espacio, coma, punto y dos puntos.
;   - Movimiento del cursor con las cuatro flechas, limitado al area de texto.
;   - ESC vuelve al programa que llamo al editor.
;
; Pendiente para las siguientes partes: archivos, ALT+S, colores, imagenes,
; buscar/reemplazar y la pantalla de ayuda.

.model small
.stack 100h

EDIT_TOP    EQU 3
EDIT_BOTTOM EQU 21
TEXT_ATTR   EQU 0Fh

.data
titleLine   db '  EDITOR DE TEXTO  |  Documento sin guardar', 0
borderLine  db '--------------------------------------------------------------------------------', 0
hintLine    db 'Flechas: mover  |  A-Z, 0-9, espacio, , . :  |  ESC: volver', 0
statusLine  db 'Estado: EDITANDO', 0

cursorRow   db EDIT_TOP
cursorCol   db 0

.code
main PROC
    mov ax, @data
    mov ds, ax

    call PantallaEdicion

    mov ax, 4C00h
    int 21h
main ENDP

; Dibuja la interfaz y conserva el control hasta que se presione ESC.
PantallaEdicion PROC NEAR
    mov ax, 0003h                 ; modo texto 80x25 y limpiar pantalla
    int 10h

    mov dh, 0
    mov dl, 0
    mov si, OFFSET titleLine
    mov bl, 1Fh
    call ImprimirCadena

    mov dh, 1
    mov dl, 0
    mov si, OFFSET borderLine
    mov bl, 1Bh
    call ImprimirCadena

    mov dh, 22
    mov dl, 0
    mov si, OFFSET borderLine
    mov bl, 1Bh
    call ImprimirCadena

    mov dh, 23
    mov dl, 1
    mov si, OFFSET hintLine
    mov bl, 0Ah
    call ImprimirCadena

    mov dh, 24
    mov dl, 1
    mov si, OFFSET statusLine
    mov bl, 0Eh
    call ImprimirCadena

    mov cursorRow, EDIT_TOP
    mov cursorCol, 0

LeerTecla:
    call ColocarCursor
    mov ah, 00h
    int 16h

    cmp al, 27                    ; ESC: regresar al menu principal al integrarlo
    je  FinEditor

    cmp al, 0
    je  TeclaExtendida

    call EsCaracterPermitido
    jc  LeerTecla                 ; no se dibuja una tecla no permitida
    call EscribirCaracter
    jmp LeerTecla

TeclaExtendida:
    cmp ah, 48h                   ; flecha arriba
    je  Subir
    cmp ah, 50h                   ; flecha abajo
    je  Bajar
    cmp ah, 4Bh                   ; flecha izquierda
    je  Izquierda
    cmp ah, 4Dh                   ; flecha derecha
    je  Derecha
    jmp LeerTecla

Subir:
    cmp cursorRow, EDIT_TOP
    je  LeerTecla
    dec cursorRow
    jmp LeerTecla

Bajar:
    cmp cursorRow, EDIT_BOTTOM
    je  LeerTecla
    inc cursorRow
    jmp LeerTecla

Izquierda:
    cmp cursorCol, 0
    jne MoverIzquierda
    cmp cursorRow, EDIT_TOP
    je  LeerTecla
    dec cursorRow
    mov cursorCol, 79
    jmp LeerTecla
MoverIzquierda:
    dec cursorCol
    jmp LeerTecla

Derecha:
    cmp cursorCol, 79
    jne MoverDerecha
    cmp cursorRow, EDIT_BOTTOM
    je  LeerTecla
    inc cursorRow
    mov cursorCol, 0
    jmp LeerTecla
MoverDerecha:
    inc cursorCol
    jmp LeerTecla

FinEditor:
    ret
PantallaEdicion ENDP

; Entrada: AL = caracter. Salida: CF=0 si es admitido; CF=1 si no lo es.
EsCaracterPermitido PROC NEAR
    cmp al, 'A'
    jb  RevisarMinuscula
    cmp al, 'Z'
    jbe Permitido
RevisarMinuscula:
    cmp al, 'a'
    jb  RevisarNumero
    cmp al, 'z'
    jbe Permitido
RevisarNumero:
    cmp al, '0'
    jb  RevisarSigno
    cmp al, '9'
    jbe Permitido
RevisarSigno:
    cmp al, ' '
    je  Permitido
    cmp al, ','
    je  Permitido
    cmp al, '.'
    je  Permitido
    cmp al, ':'
    je  Permitido
    stc
    ret
Permitido:
    clc
    ret
EsCaracterPermitido ENDP

; Escribe AL con el atributo actual y avanza una posicion sin salir del area.
EscribirCaracter PROC NEAR
    push ax
    push bx
    push cx
    push dx

    call ColocarCursor
    mov ah, 09h
    mov bh, 0
    mov bl, TEXT_ATTR
    mov cx, 1
    int 10h

    pop dx
    pop cx
    pop bx
    pop ax

    cmp cursorCol, 79
    jne AvanzarColumna
    cmp cursorRow, EDIT_BOTTOM
    je  FinEscritura
    inc cursorRow
    mov cursorCol, 0
    jmp FinEscritura
AvanzarColumna:
    inc cursorCol
FinEscritura:
    ret
EscribirCaracter ENDP

; Lleva el cursor fisico a cursorRow, cursorCol.
ColocarCursor PROC NEAR
    mov ah, 02h
    mov bh, 0
    mov dh, cursorRow
    mov dl, cursorCol
    int 10h
    ret
ColocarCursor ENDP

; Entrada: DH=fila, DL=columna, DS:SI=texto terminado en 0, BL=atributo.
ImprimirCadena PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push bp
    push di
    push es
    push si

    mov di, si
    xor cx, cx
ContarCaracter:
    cmp byte ptr [di], 0
    je  Imprimir
    inc di
    inc cx
    jmp ContarCaracter
Imprimir:
    push ds
    pop es                         ; AH=13h recibe la cadena en ES:BP
    mov bp, si
    mov ax, 1301h
    mov bh, 0
    int 10h

    pop si
    pop es
    pop di
    pop bp
    pop dx
    pop cx
    pop bx
    pop ax
    ret
ImprimirCadena ENDP

END main
