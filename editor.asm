; Proyecto 1 - Arquitectura y Diseno de Computadoras
; Avance aproximado: 60% de la pantalla de edicion (x8086 / MASM-TASM)
;
; Implementado:
;   - Marco visual y area editable de 80x25.
;   - Escritura: letras, numeros, espacio, coma, punto y dos puntos.
;   - Flechas y Backspace, limitados al area de texto.
;   - Alt+C (centrar), Alt+U (primer renglon) y Alt+D (ultimo renglon).
;   - ESC retorna al procedimiento que llama al editor.
;
; Pendiente: archivos, ALT+S, colores, imagenes, buscar/reemplazar y ayuda.

.model small
.stack 100h

EDIT_TOP    EQU 3
EDIT_BOTTOM EQU 21
TEXT_ATTR   EQU 0Fh

.data
titleLine   db '  EDITOR DE TEXTO  |  Documento sin guardar', 0
borderLine  db '--------------------------------------------------------------------------------', 0
hintLine    db 'Flechas: mover | Alt+C: centro | Alt+U/D: arriba/abajo | ESC: volver', 0
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

; Se puede llamar desde el menu principal en vez de usar main directamente.
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
    cmp al, 27                    ; ESC
    je  FinEditor
    cmp al, 8                     ; Backspace
    je  BorrarAnterior
    cmp al, 0
    je  TeclaExtendida
    call EsCaracterPermitido
    jc  LeerTecla
    call EscribirCaracter
    jmp LeerTecla

TeclaExtendida:
    ; Alt + letra se recibe como AL=0 y AH=el scan code de la letra.
    cmp ah, 2Eh                   ; Alt+C
    je  CentrarCursor
    cmp ah, 16h                   ; Alt+U
    je  IrArriba
    cmp ah, 20h                   ; Alt+D
    je  IrAbajo
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

CentrarCursor:
    mov cursorCol, 40
    jmp LeerTecla
IrArriba:
    mov cursorRow, EDIT_TOP
    jmp LeerTecla
IrAbajo:
    mov cursorRow, EDIT_BOTTOM
    jmp LeerTecla

; Retrocede una posicion, la limpia y conserva el cursor en ella.
BorrarAnterior:
    cmp cursorCol, 0
    jne RetrocederColumna
    cmp cursorRow, EDIT_TOP
    je  LeerTecla
    dec cursorRow
    mov cursorCol, 79
    jmp PintarEspacio
RetrocederColumna:
    dec cursorCol
PintarEspacio:
    call ColocarCursor
    mov al, ' '
    mov ah, 09h
    mov bh, 0
    mov bl, TEXT_ATTR
    mov cx, 1
    int 10h
    jmp LeerTecla

FinEditor:
    ret
PantallaEdicion ENDP

; Entrada AL. CF=0 si el caracter se puede escribir; CF=1 si no.
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

; Escribe AL y avanza sin salir del area editable.
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

ColocarCursor PROC NEAR
    mov ah, 02h
    mov bh, 0
    mov dh, cursorRow
    mov dl, cursorCol
    int 10h
    ret
ColocarCursor ENDP

; Entrada: DH=fila, DL=columna, DS:SI=cadena terminada en 0, BL=atributo.
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
