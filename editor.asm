; Proyecto 1 - Arquitectura y Diseno de Computadoras
; Avance aproximado: 90% de la pantalla de edicion (x8086 / MASM-TASM)
;
; Implementado:
;   - Marco visual y area editable de 80x25.
;   - Escritura: letras, numeros, espacio, coma, punto y dos puntos.
;   - Flechas y Backspace, limitados al area de texto.
;   - Alt+C (centrar), Alt+U (primer renglon) y Alt+D (ultimo renglon).
;   - Alt+M y Alt+N para alternar color de texto y fondo nuevo.
;   - Alt+I y Alt+J para insertar dos imagenes pixel art.
;   - Alt+H muestra la ayuda; Alt+S retorna AL=1 para que el menu guarde.
;   - ESC retorna al procedimiento que llama al editor.
;
; Pendiente: integracion de archivos y buscar/reemplazar (Alt+B).

.model small
.stack 100h

EDIT_TOP    EQU 3
EDIT_BOTTOM EQU 21
TEXT_ATTR   EQU 0Ch               ; rojo inicial; Alt+M rota rojo, verde y cyan
BUFFER_SIZE EQU 1520              ; 19 renglones x 80 columnas

.data
titleLine   db '  EDITOR DE TEXTO  |  Documento sin guardar', 0
borderLine  db '--------------------------------------------------------------------------------', 0
hintLine    db 'Alt+H: ayuda | Alt+M/N: colores | Alt+I/J: imagenes | Alt+S: guardar', 0
statusLine  db 'Estado: EDITANDO  |  ESC: volver sin guardar', 0
help1       db 'ATAJOS DEL EDITOR', 0
help2       db 'Alt+C  Centrar cursor       Alt+U / Alt+D  Ir arriba / abajo', 0
help3       db 'Alt+M  Alternar color letra Alt+N          Alternar color fondo', 0
help4       db 'Alt+I  Insertar imagen 1    Alt+J          Insertar imagen 2', 0
help5       db 'Alt+S  Guardar y salir      ESC            Volver sin guardar', 0
help6       db 'Flechas para mover; Backspace para borrar.  Presione una tecla...', 0
img1        db '  ^  ', ' /#\ ', '/###\'
img2        db ' [*] ', '[###]', ' [#] '
cursorRow   db EDIT_TOP
cursorCol   db 0
currentAttr db TEXT_ATTR
textColorIx db 0
backColorIx db 0
textColors  db 0Ch, 0Ah, 0Bh
backColors  db 00h, 10h, 30h      ; negro, azul y cyan
textBuffer  db BUFFER_SIZE dup (' ')
attrBuffer  db BUFFER_SIZE dup (TEXT_ATTR)

.code
main PROC
    mov ax, @data
    mov ds, ax
    call LimpiarBuffer
    call PantallaEdicion
    mov ax, 4C00h
    int 21h
main ENDP

; Se puede llamar desde el menu principal en vez de usar main directamente.
PantallaEdicion PROC NEAR
    mov ax, 0003h                 ; modo texto 80x25 y limpiar pantalla
    int 10h

    call DibujarEditor
    mov cursorRow, EDIT_TOP
    mov cursorCol, 0

LeerTecla:
    call ColocarCursor
    mov ah, 00h
    int 16h
    cmp al, 27                    ; ESC
    je  SalirSinGuardar
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
    cmp ah, 1Fh                   ; Alt+S
    je  GuardarSalir
    cmp ah, 23h                   ; Alt+H
    je  AbrirAyuda
    cmp ah, 32h                   ; Alt+M
    je  CambiarTexto
    cmp ah, 31h                   ; Alt+N
    je  CambiarFondo
    cmp ah, 17h                   ; Alt+I
    je  InsertarImagen1
    cmp ah, 24h                   ; Alt+J
    je  InsertarImagen2
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

CambiarTexto:
    inc textColorIx
    cmp textColorIx, 3
    jb  AplicarTexto
    mov textColorIx, 0
AplicarTexto:
    xor bx, bx
    mov bl, textColorIx
    mov al, currentAttr
    and al, 0F0h
    or  al, textColors[bx]
    mov currentAttr, al
    jmp LeerTecla

CambiarFondo:
    inc backColorIx
    cmp backColorIx, 3
    jb  AplicarFondo
    mov backColorIx, 0
AplicarFondo:
    xor bx, bx
    mov bl, backColorIx
    mov al, currentAttr
    and al, 0Fh
    or  al, backColors[bx]
    mov currentAttr, al
    jmp LeerTecla

InsertarImagen1:
    mov si, OFFSET img1
    call InsertarImagen
    jmp LeerTecla
InsertarImagen2:
    mov si, OFFSET img2
    call InsertarImagen
    jmp LeerTecla

AbrirAyuda:
    call MostrarAyuda
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
    call IndiceCursor
    mov textBuffer[di], ' '
    mov al, currentAttr
    mov attrBuffer[di], al
    call ColocarCursor
    mov al, ' '
    mov ah, 09h
    mov bh, 0
    mov bl, currentAttr
    mov cx, 1
    int 10h
    jmp LeerTecla

GuardarSalir:
    mov al, 1                     ; el llamador debe guardar los buffers
    ret
SalirSinGuardar:
    xor al, al
    ret
PantallaEdicion ENDP

; Reinicia el contenido y sus atributos antes de entrar al editor.
LimpiarBuffer PROC NEAR
    push ax
    push cx
    push di
    push es
    push ds
    pop es
    mov di, OFFSET textBuffer
    mov al, ' '
    mov cx, BUFFER_SIZE
    rep stosb
    mov di, OFFSET attrBuffer
    mov al, TEXT_ATTR
    mov cx, BUFFER_SIZE
    rep stosb
    pop es
    pop di
    pop cx
    pop ax
    ret
LimpiarBuffer ENDP

; Convierte cursorRow/cursorCol al indice de los buffers en DI.
IndiceCursor PROC NEAR
    xor ax, ax
    mov al, cursorRow
    sub al, EDIT_TOP
    mov bl, 80
    mul bl
    xor bx, bx
    mov bl, cursorCol
    add ax, bx
    mov di, ax
    ret
IndiceCursor ENDP

; Vuelve a dibujar el marco sin borrar los buffers.
DibujarEditor PROC NEAR
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
    call PintarBuffer
    ret
DibujarEditor ENDP

; Pinta el texto y los atributos guardados, conservando la posicion del cursor.
PintarBuffer PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push di
    mov al, cursorRow
    push ax
    mov al, cursorCol
    push ax
    mov cursorRow, EDIT_TOP
    mov cursorCol, 0
    xor di, di
    mov cx, BUFFER_SIZE
PintarCelda:
    call ColocarCursor
    mov al, textBuffer[di]
    mov bl, attrBuffer[di]
    push cx
    mov cx, 1
    mov ah, 09h
    mov bh, 0
    int 10h
    pop cx
    inc di
    inc cursorCol
    cmp cursorCol, 80
    jb  SiguienteCelda
    mov cursorCol, 0
    inc cursorRow
SiguienteCelda:
    loop PintarCelda
    pop ax
    mov cursorCol, al
    pop ax
    mov cursorRow, al
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PintarBuffer ENDP

; Inserta en el cursor una imagen de 3x5 recibida en DS:SI.
InsertarImagen PROC NEAR
    push ax
    push bx
    push bp
    push si
    mov al, cursorRow
    push ax
    mov al, cursorCol
    push ax
    cmp cursorRow, 19             ; se necesitan tres renglones disponibles
    ja  FinImagen
    cmp cursorCol, 75
    ja  FinImagen
    mov bp, 3
FilaImagen:
    mov bx, 5
ColumnaImagen:
    push bx
    call IndiceCursor
    pop bx
    mov al, [si]
    mov textBuffer[di], al
    mov attrBuffer[di], 0Eh
    call ColocarCursor
    mov ah, 09h
    mov bh, 0
    mov bl, 0Eh
    mov cx, 1
    int 10h
    inc si
    inc cursorCol
    dec bx
    jnz ColumnaImagen
    sub cursorCol, 5
    inc cursorRow
    dec bp
    jnz FilaImagen
FinImagen:
    pop ax
    mov cursorCol, al
    pop ax
    mov cursorRow, al
    pop si
    pop bp
    pop bx
    pop ax
    ret
InsertarImagen ENDP

MostrarAyuda PROC NEAR
    mov ax, 0003h
    int 10h
    mov dh, 3
    mov dl, 25
    mov si, OFFSET help1
    mov bl, 1Fh
    call ImprimirCadena
    mov dh, 6
    mov dl, 3
    mov si, OFFSET help2
    mov bl, 0Fh
    call ImprimirCadena
    mov dh, 8
    mov dl, 3
    mov si, OFFSET help3
    mov bl, 0Fh
    call ImprimirCadena
    mov dh, 10
    mov dl, 3
    mov si, OFFSET help4
    mov bl, 0Fh
    call ImprimirCadena
    mov dh, 12
    mov dl, 3
    mov si, OFFSET help5
    mov bl, 0Fh
    call ImprimirCadena
    mov dh, 17
    mov dl, 3
    mov si, OFFSET help6
    mov bl, 0Ah
    call ImprimirCadena
    mov ah, 00h
    int 16h
    mov ax, 0003h
    int 10h
    call DibujarEditor
    ret
MostrarAyuda ENDP

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
    mov bl, currentAttr
    mov cx, 1
    int 10h
    pop dx
    pop cx
    pop bx
    pop ax

    push ax
    call IndiceCursor
    pop ax
    mov textBuffer[di], al
    mov bl, currentAttr
    mov attrBuffer[di], bl
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
