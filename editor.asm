; Proyecto 1 - Arquitectura y Diseno de Computadoras
; Pantalla de edicion terminada (x8086 / MASM-TASM)
;
; Implementado:
;   - Marco visual y area editable de 80x25.
;   - Escritura: letras, numeros, espacio, coma, punto y dos puntos.
;   - Flechas y Backspace, limitados al area de texto.
;   - Alt+C (centrar), Alt+U (primer renglon) y Alt+D (ultimo renglon).
;   - Alt+M y Alt+N para alternar color de texto y fondo nuevo.
;   - Alt+I y Alt+J para insertar dos imagenes pixel art.
;   - Alt+H muestra la ayuda; Alt+S retorna AL=1 para que el menu guarde.
;   - Alt+B busca y reemplaza todas las coincidencias del documento.
;   - ESC retorna al procedimiento que llama al editor.
;
; La creacion, apertura y escritura del archivo se conectan desde el menu.

.model small
.stack 100h

EDIT_TOP    EQU 3
EDIT_BOTTOM EQU 21
TEXT_ATTR   EQU 0Ch               ; rojo inicial; Alt+M rota rojo, verde y cyan
BUFFER_SIZE EQU 1520              ; 19 renglones x 80 columnas
MAX_FILES   EQU 10

.data
titleLine   db '  EDITOR DE TEXTO  |  Documento sin guardar', 0
borderLine  db '--------------------------------------------------------------------------------', 0
hintLine    db 'Alt+H: ayuda | Alt+M/N: colores | Alt+I/J: imagenes | Alt+S: guardar', 0
statusLine  db 'Estado: EDITANDO  |  ESC: volver sin guardar', 0
emptyLine   db 80 dup (' '), 0
activeName  db 'DOCUMENT.EDT', 0  ; nombre activo, actualizado por el navegador
dirtyText   db '*', 0
cleanText   db ' ', 0
labelFila   db 'F:', 0
labelCol    db 'C:', 0
labelText   db 'T:', 0
labelBack   db 'B:', 0
help1       db 'ATAJOS DEL EDITOR', 0
help2       db 'Alt+C  Centrar cursor       Alt+U / Alt+D  Ir arriba / abajo', 0
help3       db 'Alt+M  Alternar color letra Alt+N          Alternar color fondo', 0
help4       db 'Alt+I  Insertar imagen 1    Alt+J          Insertar imagen 2', 0
help5       db 'Alt+B  Buscar y reemplazar  Alt+S          Guardar y salir', 0
help6       db 'Flechas para mover; Backspace para borrar.  ESC vuelve sin guardar.', 0
help7       db 'Presione una tecla para volver al documento...', 0
findLabel   db 'Buscar: ', 0
replaceLabel db 'Reemplazar con: ', 0
replaceNote db 'El reemplazo ocupa el mismo espacio que la palabra buscada.', 0
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
findInput   db 15, 0, 15 dup (0) ; formato de entrada DOS AH=0Ah
replaceInput db 15, 0, 15 dup (0)
findLen     db 0
replaceLen  db 0
searchLimit dw 0
dirtyFlag   db 0
dtaBuffer   db 128 dup (0)
filePattern db '*.EDT', 0
fileList    db MAX_FILES * 13 dup (0)
fileCount   db 0
fileIndex   db 0
browserTitle db 'NAVEGADOR DE ARCHIVOS .EDT', 0
browserHint db 'Flechas: seleccionar   Enter: abrir   ESC: cancelar', 0
noFilesText db 'No hay archivos .EDT en esta carpeta.', 0
selectMark  db '>', 0

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
    call ActualizarEstado
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
    cmp ah, 30h                   ; Alt+B
    je  BuscarYReemplazar
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
    mov dirtyFlag, 1
    jmp LeerTecla
InsertarImagen2:
    mov si, OFFSET img2
    call InsertarImagen
    mov dirtyFlag, 1
    jmp LeerTecla

BuscarYReemplazar:
    call BuscarReemplazar
    mov dirtyFlag, 1
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
    mov dirtyFlag, 1
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
    mov dirtyFlag, 0
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
    call ActualizarEstado
    call PintarBuffer
    ret
DibujarEditor ENDP

; Barra de estado: archivo, cambios pendientes, fila, columna y colores activos.
ActualizarEstado PROC NEAR
    push ax
    push bx
    push dx
    push si
    mov dh, 24
    mov dl, 0
    mov si, OFFSET emptyLine
    mov bl, 17h
    call ImprimirCadena
    mov dh, 24
    mov dl, 0
    mov si, OFFSET activeName
    mov bl, 0Eh
    call ImprimirCadena
    mov dh, 24
    mov dl, 14
    cmp dirtyFlag, 0
    je  EstadoLimpio
    mov si, OFFSET dirtyText
    jmp ImprimirMarca
EstadoLimpio:
    mov si, OFFSET cleanText
ImprimirMarca:
    mov bl, 0Ch
    call ImprimirCadena
    mov dh, 24
    mov dl, 17
    mov si, OFFSET labelFila
    mov bl, 0Fh
    call ImprimirCadena
    mov al, cursorRow
    sub al, EDIT_TOP-1
    mov dh, 24
    mov dl, 19
    call ImprimirNumero2
    mov dh, 24
    mov dl, 23
    mov si, OFFSET labelCol
    mov bl, 0Fh
    call ImprimirCadena
    mov al, cursorCol
    inc al
    mov dh, 24
    mov dl, 25
    call ImprimirNumero2
    mov dh, 24
    mov dl, 29
    mov si, OFFSET labelText
    mov bl, 0Fh
    call ImprimirCadena
    mov al, currentAttr
    and al, 0Fh
    mov dh, 24
    mov dl, 31
    call ImprimirNumero2
    mov dh, 24
    mov dl, 35
    mov si, OFFSET labelBack
    mov bl, 0Fh
    call ImprimirCadena
    mov al, currentAttr
    shr al, 1
    shr al, 1
    shr al, 1
    shr al, 1
    mov dh, 24
    mov dl, 37
    call ImprimirNumero2
    pop si
    pop dx
    pop bx
    pop ax
    ret
ActualizarEstado ENDP

; Imprime AL como dos digitos en DH:DL, con atributo amarillo.
ImprimirNumero2 PROC NEAR
    push ax
    push bx
    push cx
    push dx
    xor ah, ah
    mov bl, 10
    div bl
    push ax
    add al, '0'
    mov ah, 09h
    mov bh, 0
    mov bl, 0Eh
    mov cx, 1
    int 10h
    pop ax
    inc dl
    mov al, ah
    add al, '0'
    mov ah, 09h
    mov bh, 0
    mov bl, 0Eh
    mov cx, 1
    int 10h
    pop dx
    pop cx
    pop bx
    pop ax
    ret
ImprimirNumero2 ENDP

; Navegador extra: deja en activeName el .EDT elegido. CF=0 si se eligio uno.
; El menu principal puede llamar a esta rutina antes de cargar el archivo.
NavegadorArchivos PROC NEAR
    call CargarListaArchivos
    mov ax, 0003h
    int 10h
    cmp fileCount, 0
    jne MostrarLista
    mov dh, 10
    mov dl, 18
    mov si, OFFSET noFilesText
    mov bl, 0Ch
    call ImprimirCadena
    mov ah, 00h
    int 16h
    stc
    ret
MostrarLista:
    mov fileIndex, 0
RedibujarLista:
    call DibujarNavegador
EsperarArchivo:
    mov ah, 00h
    int 16h
    cmp al, 27
    je  CancelarArchivo
    cmp al, 13
    je  ElegirArchivo
    cmp al, 0
    jne EsperarArchivo
    cmp ah, 48h
    je  ArchivoArriba
    cmp ah, 50h
    je  ArchivoAbajo
    jmp EsperarArchivo
ArchivoArriba:
    cmp fileIndex, 0
    je  EsperarArchivo
    dec fileIndex
    jmp RedibujarLista
ArchivoAbajo:
    mov al, fileCount
    dec al
    cmp fileIndex, al
    je  EsperarArchivo
    inc fileIndex
    jmp RedibujarLista
ElegirArchivo:
    call CopiarArchivoActivo
    mov dirtyFlag, 0
    clc
    ret
CancelarArchivo:
    stc
    ret
NavegadorArchivos ENDP

; Carga hasta diez coincidencias *.EDT usando FindFirst/FindNext de DOS.
CargarListaArchivos PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    push es
    push ds
    pop es
    mov fileCount, 0
    mov dx, OFFSET dtaBuffer
    mov ah, 1Ah
    int 21h
    mov dx, OFFSET filePattern
    xor cx, cx
    mov ah, 4Eh
    int 21h
    jc  FinCarga
SiguienteArchivo:
    cmp fileCount, MAX_FILES
    jae FinCarga
    xor ax, ax
    mov al, fileCount
    mov bl, 13
    mul bl
    mov di, ax
    add di, OFFSET fileList
    mov si, OFFSET dtaBuffer+30  ; nombre ASCIIZ dentro del DTA
    mov cx, 13
    rep movsb
    inc fileCount
    mov ah, 4Fh
    int 21h
    jnc SiguienteArchivo
FinCarga:
    pop es
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
CargarListaArchivos ENDP

DibujarNavegador PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    push bp
    mov ax, 0003h
    int 10h
    mov dh, 1
    mov dl, 24
    mov si, OFFSET browserTitle
    mov bl, 1Fh
    call ImprimirCadena
    mov dh, 23
    mov dl, 12
    mov si, OFFSET browserHint
    mov bl, 0Ah
    call ImprimirCadena
    xor bp, bp
    mov si, OFFSET fileList
    xor cx, cx
    mov cl, fileCount
    mov dh, 5
LineaArchivo:
    mov dl, 0
    push si
    mov si, OFFSET emptyLine
    mov bl, 07h
    call ImprimirCadena
    pop si
    mov ax, bp
    cmp al, fileIndex
    jne ArchivoNormal
    mov dl, 1
    push si
    mov si, OFFSET selectMark
    mov bl, 0Eh
    call ImprimirCadena
    pop si
    mov bl, 1Eh
    jmp ImprimirArchivo
ArchivoNormal:
    mov bl, 0Fh
ImprimirArchivo:
    mov dl, 4
    call ImprimirCadena
    add si, 13
    inc bp
    inc dh
    loop LineaArchivo
    pop bp
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DibujarNavegador ENDP

CopiarArchivoActivo PROC NEAR
    push ax
    push bx
    push cx
    push di
    push si
    push es
    push ds
    pop es
    xor ax, ax
    mov al, fileIndex
    mov bl, 13
    mul bl
    mov si, ax
    add si, OFFSET fileList
    mov di, OFFSET activeName
    mov cx, 13
    rep movsb
    pop es
    pop si
    pop di
    pop cx
    pop bx
    pop ax
    ret
CopiarArchivoActivo ENDP

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
    mov dh, 20
    mov dl, 12
    mov si, OFFSET help7
    mov bl, 0Eh
    call ImprimirCadena
    mov ah, 00h
    int 16h
    mov ax, 0003h
    int 10h
    call DibujarEditor
    ret
MostrarAyuda ENDP

; Solicita dos palabras con la entrada DOS y redibuja el documento al terminar.
BuscarReemplazar PROC NEAR
    mov ax, 0003h
    int 10h
    mov dh, 7
    mov dl, 5
    mov si, OFFSET findLabel
    mov bl, 0Fh
    call ImprimirCadena
    mov dh, 7
    mov dl, 13
    call ColocarCursorDirecto
    mov dx, OFFSET findInput
    mov ah, 0Ah
    int 21h
    mov al, findInput+1
    mov findLen, al

    mov dh, 10
    mov dl, 5
    mov si, OFFSET replaceLabel
    mov bl, 0Fh
    call ImprimirCadena
    mov dh, 10
    mov dl, 21
    call ColocarCursorDirecto
    mov dx, OFFSET replaceInput
    mov ah, 0Ah
    int 21h
    mov al, replaceInput+1
    cmp al, findLen               ; se conserva el ancho del documento
    jbe LongitudValida
    mov al, findLen
LongitudValida:
    mov replaceLen, al

    mov dh, 14
    mov dl, 5
    mov si, OFFSET replaceNote
    mov bl, 0Eh
    call ImprimirCadena
    call ReemplazarCoincidencias
    mov ax, 0003h
    int 10h
    call DibujarEditor
    ret
BuscarReemplazar ENDP

; Reemplaza todas las apariciones. Las palabras cortas se completan con espacios
; para conservar la matriz fija de 19x80 que usa la pantalla.
ReemplazarCoincidencias PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    cmp findLen, 0
    je  FinReemplazo
    xor ax, ax
    mov al, findLen
    mov bx, BUFFER_SIZE
    sub bx, ax
    mov searchLimit, bx
    xor si, si
BuscarSiguiente:
    cmp si, searchLimit
    ja  FinReemplazo
    mov di, si
    mov bx, OFFSET findInput+2
    xor cx, cx
    mov cl, findLen
CompararLetra:
    mov al, textBuffer[di]
    cmp al, [bx]
    jne SinCoincidencia
    inc di
    inc bx
    loop CompararLetra

    mov di, si
    mov bx, OFFSET replaceInput+2
    xor cx, cx
    mov cl, replaceLen
CopiarReemplazo:
    jcxz CompletarEspacios
    mov al, [bx]
    mov textBuffer[di], al
    mov al, currentAttr
    mov attrBuffer[di], al
    inc di
    inc bx
    loop CopiarReemplazo
CompletarEspacios:
    xor cx, cx
    mov cl, findLen
    sub cl, replaceLen
RellenarEspacio:
    jcxz AvanzarCoincidencia
    mov textBuffer[di], ' '
    mov al, currentAttr
    mov attrBuffer[di], al
    inc di
    loop RellenarEspacio
AvanzarCoincidencia:
    xor ax, ax
    mov al, findLen
    add si, ax
    jmp BuscarSiguiente
SinCoincidencia:
    inc si
    jmp BuscarSiguiente
FinReemplazo:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
ReemplazarCoincidencias ENDP

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
    mov dirtyFlag, 1
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

; Posiciona el cursor usando directamente DH=fila y DL=columna.
ColocarCursorDirecto PROC NEAR
    mov ah, 02h
    mov bh, 0
    int 10h
    ret
ColocarCursorDirecto ENDP

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
