; Proyecto 1 - Arquitectura y Diseno de Computadoras
; Pantalla de edicion VGA 320x200x256 (modo 13h, x8086 / MASM-TASM)
;
; Implementado:
;   - Marco visual y area editable de 80x25.
;   - Escritura: letras, numeros, espacio, coma, punto y dos puntos.
;   - Flechas y Backspace, limitados al area de texto.
;   - TAB+C (centrar), TAB+U (primer renglon) y TAB+D (ultimo renglon).
;   - TAB+M y TAB+N para alternar color de texto y fondo nuevo.
;   - TAB+I y TAB+J para insertar dos imagenes pixel art.
;   - TAB+H muestra la ayuda; TAB+S retorna AL=1 para que el menu guarde.
;   - TAB+O abre el navegador de archivos .EDT.
;   - TAB+R regresa sin guardar.
;   - TAB+B busca y reemplaza todas las coincidencias del documento.
;   - ESC retorna al procedimiento que llama al editor.
;
; La creacion, apertura y escritura del archivo se conectan desde el menu.

.model small
.stack 100h

EDIT_TOP    EQU 3
EDIT_BOTTOM EQU 21
EDIT_COLS   EQU 40               ; 320 pixeles / fuente BIOS de 8 pixeles
TEXT_ATTR   EQU 255               ; blanco: indice VGA dentro de 0..255
BUFFER_SIZE EQU 760               ; 19 renglones x 40 columnas
MAX_FILES   EQU 10

; Panel de edicion en pixeles: cubre justo los renglones escribibles.
PANEL_TOP    EQU 16
PANEL_BOTTOM EQU 175
PANEL_LEFT   EQU 4
PANEL_RIGHT  EQU 315

.data
titleLine   db '  BLOC DE NOTAS VGA', 0
borderLine  db '----------------------------------------', 0
hintLine    db 'TAB+H ayuda TAB+M/N color TAB+S guarda', 0
statusLine  db 'Bloc de notas: EDITANDO', 0
emptyLine   db EDIT_COLS dup (' '), 0
activeName  db 'DOCUMENT.EDT', 0  ; nombre activo, actualizado por el navegador
txtFileName db 'DOCUMENT.TXT', 0
htmlFileName db 'DOCUMENT.HTM', 0   ; DOS 8.3: la extension es de 3 letras
saveEdtPath  db 'D:\DOCUMENT.EDT', 0
saveTxtPath  db 'D:\DOCUMENT.TXT', 0
saveHtmlPath db 'D:\DOCUMENT.HTM', 0
baseName    db 8 dup (0)          ; nombre sin extension, compartido por los 3
baseLen     db 0
namePrompt  db 'Nombre base (max 8 letras) y ENTER:', 0
savedMsg    db 'GUARDADO EN D: (TXT HTM EDT):', 0
localSavedMsg db 'GUARDADO LOCAL (monta D: para Escritorio):', 0
nameInput   db 8, 0, 8 dup (0)
dirtyText   db '*', 0
cleanText   db ' ', 0
labelFila   db 'F:', 0
labelCol    db 'C:', 0
labelText   db 'T:', 0
labelBack   db 'B:', 0
help1       db 'BLOC DE NOTAS VGA', 0
help2       db 'TAB+C centro TAB+U/D arriba/abajo', 0
help3       db 'TAB+M letra TAB+N fondo', 0
help4       db 'TAB+I/J imagen 1/2', 0
help5       db 'TAB+B busca O abre archivos', 0
help6       db 'Flechas Backspace editan. TAB+R vuelve.', 0
help7       db 'Presione una tecla para volver.', 0
findLabel   db 'Buscar: ', 0
replaceLabel db 'Reemplazar con: ', 0
replaceNote db 'El reemplazo ocupa el mismo espacio que la palabra buscada.', 0
img1        db '  ^  ', ' /#\ ', '/###\'
img2        db ' [*] ', '[###]', ' [#] '
cursorRow   db EDIT_TOP
cursorCol   db 0
currentAttr db TEXT_ATTR          ; color de letra VGA, 0..255
currentBackColor db 1             ; color de fondo VGA, 0..255
textColorIx db 0
backColorIx db 0
textColors  db 255, 28, 15        ; blanco, rosa, blanco brillante
backColors  db 1, 0, 28           ; morado, contorno, rosa
textBuffer  db BUFFER_SIZE dup (' ')
attrBuffer  db BUFFER_SIZE dup (TEXT_ATTR)
findInput   db 15, 0, 15 dup (0) ; formato de entrada DOS AH=0Ah
replaceInput db 15, 0, 15 dup (0)
findLen     db 0
replaceLen  db 0
lineBuffer  db 42 dup (0)         ; 40 caracteres + CR/LF para exportar TXT
edtHeader   db 0, 0, 0, 0         ; fondo, color actual, ancho, alto
saveOk      db 1
; El HTML se arma en memoria: el fondo y el color de cada letra salen de la
; paleta VGA real, no de un color fijo.
htmlHead1   db '<html><body style="margin:0;background:#'
htmlHead1End LABEL BYTE
htmlHead2   db '"><pre style="font:16px monospace;line-height:1.1;padding:16px">',13,10
htmlHead2End LABEL BYTE
spanOpen1   db '<span style="color:#'
spanOpen1End LABEL BYTE
spanOpen2   db '">'
spanOpen2End LABEL BYTE
spanClose   db '</span>'
spanCloseEnd LABEL BYTE
htmlFoot    db '</pre></body></html>',13,10
htmlFootEnd LABEL BYTE
spanAbierto db 0
spanColor   db 0
htmlLine    db 1700 dup (0)       ; una fila de HTML ya con sus etiquetas
searchLimit dw 0
dirtyFlag   db 0
commandMode db 0                  ; 1 despues de TAB: la siguiente letra es comando
dtaBuffer   db 128 dup (0)
filePattern db 'D:\*.EDT', 0      ; se guarda y se busca en la raiz de D:
fileList    db MAX_FILES * 13 dup (0)
fileCount   db 0
fileIndex   db 0
browserTitle db 'NAVEGADOR .EDT', 0
browserHint db 'Flechas Enter abre ESC sale', 0
noFilesText db 'No hay archivos .EDT en esta carpeta.', 0
selectMark  db '>', 0
fontSeg     dw 0                  ; segmento de la tabla de fuente 8x8 de la BIOS
fontOff     dw 0                  ; offset de la tabla de fuente 8x8 de la BIOS
glyphBuf    db 8 dup (0)          ; copia local de los 8 bytes del glifo actual
maskFondo   db 0FFh               ; que pixeles de la celda caen dentro del panel
filaDentro  db 0
yGlifo      dw 0                  ; linea de pixeles que se esta dibujando

.code
main PROC
    mov ax, @data
    mov ds, ax
    call LimpiarBuffer
    call PantallaEdicion
    mov ax, 4C00h
    int 21h
main ENDP

; Carga los tres colores propios sin tocar la pantalla. Se usa por separado
; para poder restaurar un documento guardado sin borrar lo que se dibujo.
ConfigurarPaletaVGA PROC NEAR
    push ax
    push dx
    mov dx, 03C8h
    xor al, al
    out dx, al
    mov dx, 03C9h                 ; paleta 0: azul muy oscuro
    mov al, 8
    out dx, al
    mov al, 8
    out dx, al
    mov al, 16
    out dx, al
    mov dx, 03C8h
    mov al, 1
    out dx, al
    mov dx, 03C9h                 ; paleta 1: morado de Menu
    mov al, 24
    out dx, al
    mov al, 20
    out dx, al
    mov al, 28
    out dx, al
    mov dx, 03C8h
    mov al, 28
    out dx, al
    mov dx, 03C9h                 ; paleta 28: rosa, tercer fondo TAB+N
    mov al, 48
    out dx, al
    mov al, 10
    out dx, al
    mov al, 42
    out dx, al
    pop dx
    pop ax
    ret
ConfigurarPaletaVGA ENDP

; Tema tomado de la rama Menu: borde azul oscuro y panel morado en modo 13h.
TemaMenuVGA PROC NEAR
    push bx                         ; conservar el color solicitado en BL
    push ax
    push cx
    push dx
    push di
    push es
    call ConfigurarPaletaVGA
    mov ax, 0A000h
    mov es, ax
    xor di, di
    xor al, al
    mov cx, 64000
    cld
    rep stosb
    mov di, PANEL_TOP*320+PANEL_LEFT
    mov cx, PANEL_BOTTOM-PANEL_TOP+1
RellenarPanelMenu:
    push cx
    mov cx, PANEL_RIGHT-PANEL_LEFT+1
    mov al, currentBackColor      ; TAB+N cambia el panel completo
    rep stosb
    pop cx
    add di, 320-(PANEL_RIGHT-PANEL_LEFT+1)
    loop RellenarPanelMenu
    pop es
    pop di
    pop dx
    pop cx
    pop ax
    pop bx
    ret
TemaMenuVGA ENDP

; Se puede llamar desde el menu principal en vez de usar main directamente.
PantallaEdicion PROC NEAR
    mov ax, 0013h                 ; VGA: 320x200, 256 colores
    int 10h
    call ObtenerFuente

    call DibujarEditor
    mov cursorRow, EDIT_TOP
    mov cursorCol, 0

LeerTecla:
    call ActualizarEstado
    call ColocarCursor
    mov ah, 00h
    int 16h
    cmp al, 9                     ; TAB abre una orden de una letra
    jne RevisarComandoTab
    mov commandMode, 1
    jmp LeerTecla
RevisarComandoTab:
    cmp commandMode, 1
    jne TeclaNormal
    mov commandMode, 0
    or  al, 20h                   ; acepta mayusculas o minusculas
    cmp al, 's'
    jne TabNoS
    jmp GuardarSalir
TabNoS:
    cmp al, 'h'
    jne TabNoH
    jmp AbrirAyuda
TabNoH:
    cmp al, 'm'
    jne TabNoO
    jmp CambiarTexto
TabNoO:
    cmp al, 'o'
    jne TabNoM
    jmp AbrirNavegador
TabNoM:
    cmp al, 'n'
    jne TabNoN
    jmp CambiarFondo
TabNoN:
    cmp al, 'i'
    jne TabNoI
    jmp InsertarImagen1
TabNoI:
    cmp al, 'j'
    jne TabNoJ
    jmp InsertarImagen2
TabNoJ:
    cmp al, 'b'
    jne TabNoB
    jmp BuscarYReemplazar
TabNoB:
    cmp al, 'c'
    jne TabNoC
    jmp CentrarCursor
TabNoC:
    cmp al, 'u'
    jne TabNoU
    jmp IrArriba
TabNoU:
    cmp al, 'd'
    jne TabNoD
    jmp IrAbajo
TabNoD:
    cmp al, 'r'
    jne ComandoTabInvalido        ; TAB+otra tecla no debe escribir texto
    jmp SalirSinGuardar
ComandoTabInvalido:
    jmp LeerTecla
TeclaNormal:
    cmp al, 27                    ; ESC
    jne NoSalirSinGuardar
    jmp SalirSinGuardar
NoSalirSinGuardar:
    cmp al, 8                     ; Backspace
    jne NoBorrarAnterior
    jmp BorrarAnterior
NoBorrarAnterior:
    cmp al, 0
    je  TeclaExtendida
    call EsCaracterPermitido
    jnc CaracterValido
    jmp LeerTecla                 ; TASM: salto lejano, no condicional corto
CaracterValido:
    call EscribirCaracter
    jmp LeerTecla

TeclaExtendida:
    ; Solo flechas: los comandos usan TAB + letra.
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
    jne PuedeSubir
    jmp LeerTecla
PuedeSubir:
    dec cursorRow
    jmp LeerTecla
Bajar:
    cmp cursorRow, EDIT_BOTTOM
    jne PuedeBajar
    jmp LeerTecla
PuedeBajar:
    inc cursorRow
    jmp LeerTecla
Izquierda:
    cmp cursorCol, 0
    jne MoverIzquierda
    cmp cursorRow, EDIT_TOP
    jne PuedeIrIzquierda
    jmp LeerTecla
PuedeIrIzquierda:
    dec cursorRow
    mov cursorCol, EDIT_COLS-1
    jmp LeerTecla
MoverIzquierda:
    dec cursorCol
    jmp LeerTecla
Derecha:
    cmp cursorCol, EDIT_COLS-1
    jne MoverDerecha
    cmp cursorRow, EDIT_BOTTOM
    jne PuedeIrDerecha
    jmp LeerTecla
PuedeIrDerecha:
    inc cursorRow
    mov cursorCol, 0
    jmp LeerTecla
MoverDerecha:
    inc cursorCol
    jmp LeerTecla

CentrarCursor:
    mov cursorCol, EDIT_COLS/2
    call DibujarEditor
    call DibujarCursorVGA
    jmp LeerTecla
IrArriba:
    mov cursorRow, EDIT_TOP
    call DibujarEditor
    call DibujarCursorVGA
    jmp LeerTecla
IrAbajo:
    mov cursorRow, EDIT_BOTTOM
    mov cursorCol, 0
    call DibujarEditor
    call DibujarCursorVGA
    jmp LeerTecla

CambiarTexto:
    inc textColorIx
    cmp textColorIx, 3
    jb  AplicarTexto
    mov textColorIx, 0
AplicarTexto:
    xor bx, bx
    mov bl, textColorIx
    mov al, textColors[bx]
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
    mov al, backColors[bx]
    mov currentBackColor, al
    call DibujarEditor
    jmp LeerTecla

InsertarImagen1:
    call DibujarNyanVGA
    mov dirtyFlag, 1
    jmp LeerTecla
InsertarImagen2:
    call DibujarTotemVGA
    mov dirtyFlag, 1
    jmp LeerTecla

BuscarYReemplazar:
    call BuscarReemplazar
    mov dirtyFlag, 1
    jmp LeerTecla

AbrirAyuda:
    call MostrarAyuda
    jmp LeerTecla

AbrirNavegador:
    call NavegadorArchivos
    jnc VolverDelNavegador        ; si cargo un .EDT ya dejo la pantalla lista
    mov ax, 0013h
    int 10h
    call DibujarEditor
VolverDelNavegador:
    jmp LeerTecla

; Retrocede una posicion, la limpia y conserva el cursor en ella.
BorrarAnterior:
    cmp cursorCol, 0
    jne RetrocederColumna
    cmp cursorRow, EDIT_TOP
    jne PuedeBorrar
    jmp LeerTecla
PuedeBorrar:
    dec cursorRow
    mov cursorCol, EDIT_COLS-1
    jmp PintarEspacio
RetrocederColumna:
    dec cursorCol
PintarEspacio:
    mov dirtyFlag, 1
    call IndiceCursor
    mov textBuffer[di], ' '
    mov al, currentAttr
    mov attrBuffer[di], al
    mov dh, cursorRow
    mov dl, cursorCol
    mov bl, currentAttr
    mov al, ' '
    call DibujarGlifoFondo
    jmp LeerTecla

GuardarSalir:
    call PedirNombreGuardar
    jc CancelarGuardar
    call GuardarArchivos
    mov dirtyFlag, 0
    call MostrarGuardado
    call DibujarEditor
    jmp LeerTecla
CancelarGuardar:
    jmp LeerTecla
SalirSinGuardar:
    xor al, al
    ret
PantallaEdicion ENDP

; Pide un nombre base y construye los nombres .EDT, .TXT y .HTML.
PedirNombreGuardar PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push ds
    pop es
    mov ax, 0013h
    int 10h
    call TemaMenuVGA
    mov dh, 10
    mov dl, 2
    mov si, OFFSET namePrompt
    mov bl, 255
    call ImprimirCadena
    mov byte ptr nameInput+1, 0
LeerNombreVGA:
    mov ah, 00h
    int 16h
    cmp al, 27
    jne NombreNoEsc
    jmp CancelarNombreVGA
NombreNoEsc:
    cmp al, 13
    jne NombreNoEnter
    jmp NombreListoVGA
NombreNoEnter:
    cmp al, 8
    jne NombreNoBackspace
    jmp BorrarNombreVGA
NombreNoBackspace:
    call EsCaracterPermitido
    jnc NombrePermitido
    jmp LeerNombreVGA
NombrePermitido:
    cmp nameInput+1, 8
    jb NombreHayEspacio
    jmp LeerNombreVGA
NombreHayEspacio:
    xor bx, bx
    mov bl, nameInput+1
    mov nameInput[bx+2], al
    mov dh, 12
    mov dl, 2
    add dl, nameInput+1
    mov bl, 255
    call DibujarGlifoFondo
    inc nameInput+1
    jmp LeerNombreVGA
BorrarNombreVGA:
    cmp nameInput+1, 0
    jne PuedeBorrarNombre
    jmp LeerNombreVGA
PuedeBorrarNombre:
    dec nameInput+1
    ; El color va en SI ANTES de calcular la X: PintarRectVGA recibe la X en AX.
    xor ax, ax
    mov al, currentBackColor
    mov si, ax
    xor ax, ax
    mov al, nameInput+1
    add al, 2
    shl ax, 1
    shl ax, 1
    shl ax, 1
    mov bx, 12*8
    mov cx, 8
    mov dx, 8
    call PintarRectVGA
    jmp LeerNombreVGA
NombreListoVGA:
    cmp nameInput+1, 0
    je  NombrePorDefecto
    xor cx, cx
    mov cl, nameInput+1
    mov baseLen, cl
    mov si, OFFSET nameInput+2
    mov di, OFFSET baseName
    rep movsb
    call ConstruirRutas
NombrePorDefecto:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
CancelarNombreVGA:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret
PedirNombreGuardar ENDP

; Arma activeName/txtFileName/htmlFileName y las tres rutas D:\ a partir de
; baseName/baseLen. La usan tanto el guardado como el navegador de archivos.
ConstruirRutas PROC NEAR
    push ax
    push cx
    push si
    push di
    push es
    push ds
    pop es
    cmp baseLen, 0
    jne HayBase
    jmp FinConstruirRutas
HayBase:
    mov di, OFFSET activeName
    call CopiarBase
    mov al, '.'
    stosb
    mov al, 'E'
    stosb
    mov al, 'D'
    stosb
    mov al, 'T'
    stosb
    xor al, al
    stosb

    mov di, OFFSET txtFileName
    call CopiarBase
    mov al, '.'
    stosb
    mov al, 'T'
    stosb
    mov al, 'X'
    stosb
    mov al, 'T'
    stosb
    xor al, al
    stosb

    mov di, OFFSET htmlFileName
    call CopiarBase
    mov al, '.'
    stosb
    mov al, 'H'
    stosb
    mov al, 'T'
    stosb
    mov al, 'M'
    stosb
    xor al, al
    stosb

    mov si, OFFSET activeName     ; los tres nombres caben justo tras "D:\"
    mov di, OFFSET saveEdtPath+3
    mov cx, 13
    rep movsb
    mov si, OFFSET txtFileName
    mov di, OFFSET saveTxtPath+3
    mov cx, 13
    rep movsb
    mov si, OFFSET htmlFileName
    mov di, OFFSET saveHtmlPath+3
    mov cx, 13
    rep movsb
FinConstruirRutas:
    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret
ConstruirRutas ENDP

; Copia baseLen caracteres de baseName hacia ES:DI y deja DI al final.
CopiarBase PROC NEAR
    push cx
    push si
    xor cx, cx
    mov cl, baseLen
    mov si, OFFSET baseName
    rep movsb
    pop si
    pop cx
    ret
CopiarBase ENDP

; Confirma en pantalla que el documento quedo escrito y espera una tecla.
MostrarGuardado PROC NEAR
    push ax
    push bx
    push dx
    push si
    mov dh, 16
    mov dl, 2
    mov si, OFFSET savedMsg
    cmp saveOk, 0
    jne MensajeGuardadoD
    mov si, OFFSET localSavedMsg
MensajeGuardadoD:
    mov bl, 255
    call ImprimirCadena
    mov dh, 18
    mov dl, 2
    mov si, OFFSET activeName
    mov bl, 255
    call ImprimirCadena
    mov ah, 00h
    int 16h
    pop si
    pop dx
    pop bx
    pop ax
    ret
MostrarGuardado ENDP

; Guarda una copia legible .TXT y una copia .EDT con colores/fondo.
GuardarArchivos PROC NEAR
    mov saveOk, 1
    call GuardarTXT
    call GuardarEDT
    call GuardarHTML
    ret
GuardarArchivos ENDP

GuardarTXT PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov dx, OFFSET saveTxtPath
    xor cx, cx
    mov ah, 3Ch
    int 21h
    jnc TxtAbiertoD
    mov dx, OFFSET txtFileName
    mov ah, 3Ch
    int 21h
    jc  ErrorGuardarTXT
TxtAbiertoD:
    mov bx, ax
    mov si, OFFSET textBuffer
    mov cx, 19
FilaTXT:
    push cx
    mov di, OFFSET lineBuffer
    mov cx, 40
    rep movsb
    mov al, 13
    stosb
    mov al, 10
    stosb
    mov dx, OFFSET lineBuffer
    mov cx, 42
    mov ah, 40h
    int 21h
    pop cx
    loop FilaTXT
    mov ah, 3Eh
    int 21h
    jmp FinGuardarTXT
ErrorGuardarTXT:
    mov saveOk, 0
FinGuardarTXT:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
GuardarTXT ENDP

; Exporta el documento conservando el fondo elegido y el color de cada letra.
; Los colores salen de la paleta VGA real, asi que el HTML se ve igual que el
; editor aunque el usuario cambie el tema con TAB+M / TAB+N.
GuardarHTML PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    push ds
    pop es                        ; ES=DS: las lineas se arman con movsb
    mov dx, OFFSET saveHtmlPath
    xor cx, cx
    mov ah, 3Ch
    int 21h
    jnc HtmlAbierto
    mov dx, OFFSET htmlFileName
    mov ah, 3Ch
    int 21h
    jnc HtmlAbiertoLocal
    jmp ErrorGuardarHTML
HtmlAbiertoLocal:
HtmlAbierto:
    mov bx, ax                    ; BX = handle durante toda la rutina

    mov di, OFFSET htmlLine
    mov si, OFFSET htmlHead1
    mov cx, htmlHead1End-htmlHead1
    rep movsb
    mov al, currentBackColor
    call ColorAHexVGA
    mov si, OFFSET htmlHead2
    mov cx, htmlHead2End-htmlHead2
    rep movsb
    call EscribirLineaHTML

    mov si, OFFSET textBuffer
    mov bp, OFFSET attrBuffer
    mov cx, 19
FilaHTML:
    push cx
    mov di, OFFSET htmlLine
    mov spanAbierto, 0
    mov cx, EDIT_COLS
ColumnaHTML:
    push cx
    mov al, ds:[bp]               ; color guardado de este caracter
    cmp spanAbierto, 0
    je  AbrirSpanFila
    cmp al, spanColor
    je  SoloCaracterHTML
    call CerrarSpanHTML
AbrirSpanFila:
    mov spanColor, al
    call AbrirSpanColorHTML
SoloCaracterHTML:
    mov al, [si]
    mov [di], al
    inc di
    inc si
    inc bp
    pop cx
    loop ColumnaHTML
    cmp spanAbierto, 0
    je  SinSpanAbierto
    call CerrarSpanHTML
SinSpanAbierto:
    mov al, 13
    mov [di], al
    inc di
    mov al, 10
    mov [di], al
    inc di
    call EscribirLineaHTML
    pop cx
    loop FilaHTML

    mov di, OFFSET htmlLine
    mov si, OFFSET htmlFoot
    mov cx, htmlFootEnd-htmlFoot
    rep movsb
    call EscribirLineaHTML
    mov ah, 3Eh
    int 21h
    jmp FinGuardarHTML
ErrorGuardarHTML:
    mov saveOk, 0
FinGuardarHTML:
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
GuardarHTML ENDP

; Vuelca en el handle BX lo que haya entre htmlLine y DI.
EscribirLineaHTML PROC NEAR
    push ax
    push cx
    push dx
    mov cx, di
    sub cx, OFFSET htmlLine
    mov dx, OFFSET htmlLine
    mov ah, 40h
    int 21h
    pop dx
    pop cx
    pop ax
    ret
EscribirLineaHTML ENDP

; Abre <span style="color:#RRGGBB"> en DS:DI usando spanColor.
AbrirSpanColorHTML PROC NEAR
    push ax
    push cx
    push si
    mov si, OFFSET spanOpen1
    mov cx, spanOpen1End-spanOpen1
    rep movsb
    mov al, spanColor
    call ColorAHexVGA
    mov si, OFFSET spanOpen2
    mov cx, spanOpen2End-spanOpen2
    rep movsb
    mov spanAbierto, 1
    pop si
    pop cx
    pop ax
    ret
AbrirSpanColorHTML ENDP

CerrarSpanHTML PROC NEAR
    push ax
    push cx
    push si
    mov si, OFFSET spanClose
    mov cx, spanCloseEnd-spanClose
    rep movsb
    mov spanAbierto, 0
    pop si
    pop cx
    pop ax
    ret
CerrarSpanHTML ENDP

; AL = indice de paleta. Escribe sus 6 digitos hex (RRGGBB) en DS:DI.
; Lee el DAC de la VGA, asi que sirve para cualquiera de los 256 colores.
ColorAHexVGA PROC NEAR
    push ax
    push bx
    push cx
    push dx
    mov dx, 03C7h
    out dx, al                    ; indice a leer del DAC
    mov dx, 03C9h
    mov cx, 3                     ; R, G y B
ComponenteHexVGA:
    in  al, dx
    shl al, 1                     ; el DAC guarda 6 bits: escalar a 0..255
    shl al, 1
    call ByteAHexVGA
    loop ComponenteHexVGA
    pop dx
    pop cx
    pop bx
    pop ax
    ret
ColorAHexVGA ENDP

; AL = byte. Escribe sus dos digitos hex en DS:DI y avanza DI.
ByteAHexVGA PROC NEAR
    push ax
    push bx
    mov bl, al
    shr al, 1                     ; 8086: no existe shr al, 4
    shr al, 1
    shr al, 1
    shr al, 1
    call DigitoHexVGA
    mov al, bl
    and al, 0Fh
    call DigitoHexVGA
    pop bx
    pop ax
    ret
ByteAHexVGA ENDP

; AL = 0..15. Escribe un digito hex en DS:DI y avanza DI.
DigitoHexVGA PROC NEAR
    push ax
    cmp al, 10
    jb  DigitoNumeroVGA
    add al, 'A'-10
    jmp EscribirDigitoVGA
DigitoNumeroVGA:
    add al, '0'
EscribirDigitoVGA:
    mov [di], al
    inc di
    pop ax
    ret
DigitoHexVGA ENDP

GuardarEDT PROC NEAR
    push ax
    push bx
    push cx
    push dx
    mov al, currentBackColor
    mov edtHeader, al
    mov al, currentAttr
    mov edtHeader+1, al
    mov byte ptr edtHeader+2, EDIT_COLS
    mov byte ptr edtHeader+3, 19
    mov dx, OFFSET saveEdtPath
    xor cx, cx
    mov ah, 3Ch
    int 21h
    jnc EdtAbiertoD
    mov dx, OFFSET activeName
    mov ah, 3Ch
    int 21h
    jc  ErrorGuardarEDT
EdtAbiertoD:
    mov bx, ax
    mov dx, OFFSET edtHeader
    mov cx, 4
    mov ah, 40h
    int 21h
    mov dx, OFFSET textBuffer
    mov cx, BUFFER_SIZE
    mov ah, 40h
    int 21h
    mov dx, OFFSET attrBuffer
    mov cx, BUFFER_SIZE
    mov ah, 40h
    int 21h
    ; Copia exacta de la pantalla VGA: conserva fondo, letras e imagenes.
    push ds
    mov ax, 0A000h
    mov ds, ax
    xor dx, dx
    mov cx, 64000
    mov ah, 40h
    int 21h
    pop ds
    mov ah, 3Eh
    int 21h
    jmp FinGuardarEDT
ErrorGuardarEDT:
    mov saveOk, 0
FinGuardarEDT:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
GuardarEDT ENDP

; Lee saveEdtPath y restaura fondo, color activo, texto, color por caracter y
; la pantalla completa (con las imagenes). CF=1 si el archivo no se pudo abrir.
CargarEDT PROC NEAR
    push ax
    push bx
    push cx
    push dx
    mov dx, OFFSET saveEdtPath
    mov ax, 3D00h
    int 21h
    jnc EdtAbierto
    jmp FalloCargarEDT
EdtAbierto:
    mov bx, ax
    mov dx, OFFSET edtHeader      ; fondo, color activo, ancho y alto
    mov cx, 4
    mov ah, 3Fh
    int 21h
    mov al, edtHeader
    mov currentBackColor, al
    mov al, edtHeader+1
    mov currentAttr, al
    mov dx, OFFSET textBuffer
    mov cx, BUFFER_SIZE
    mov ah, 3Fh
    int 21h
    mov dx, OFFSET attrBuffer
    mov cx, BUFFER_SIZE
    mov ah, 3Fh
    int 21h
    push bx                       ; el cambio de modo no debe perder el handle
    mov ax, 0013h
    int 10h
    call ConfigurarPaletaVGA
    pop bx
    push ds                       ; la copia de pantalla se lee directo a A000h
    mov ax, 0A000h
    mov ds, ax
    xor dx, dx
    mov cx, 64000
    mov ah, 3Fh
    int 21h
    pop ds
    mov ah, 3Eh
    int 21h
    mov cursorRow, EDIT_TOP
    mov cursorCol, 0
    mov dirtyFlag, 0
    clc
    jmp FinCargarEDT
FalloCargarEDT:
    stc
FinCargarEDT:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
CargarEDT ENDP

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
    mov bl, EDIT_COLS
    mul bl
    xor bx, bx
    mov bl, cursorCol
    add ax, bx
    mov di, ax
    ret
IndiceCursor ENDP

; Vuelve a dibujar el marco sin borrar los buffers.
DibujarEditor PROC NEAR
    call TemaMenuVGA
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
    mov dh, 24                    ; limpiar la barra antes de repintar los campos
    mov dl, 0
    mov si, OFFSET emptyLine
    mov bl, 0
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
    mov dh, 24
    mov dl, 31
    call ImprimirNumero2
    mov dh, 24
    mov dl, 35
    mov si, OFFSET labelBack
    mov bl, 0Fh
    call ImprimirCadena
    mov al, currentBackColor
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
    mov bl, 255
    call DibujarGlifoFondo
    pop ax
    inc dl
    mov al, ah
    add al, '0'
    mov bl, 255
    call DibujarGlifoFondo
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
    mov ax, 0013h
    int 10h
    call TemaMenuVGA
    mov dh, 2
    mov dl, 12
    mov si, OFFSET browserTitle
    mov bl, 255
    call ImprimirCadena
    mov dh, 22
    mov dl, 7
    mov si, OFFSET browserHint
    mov bl, 10
    call ImprimirCadena
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
    call CargarEDT                ; CF sale de aqui: 0 si el documento se cargo
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
    mov ax, 0013h
    int 10h
    call TemaMenuVGA
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

; Toma el nombre elegido en la lista, se queda con la parte previa al punto y
; deja listas las rutas .EDT, .TXT y .HTM para cargar y para el proximo guardado.
CopiarArchivoActivo PROC NEAR
    push ax
    push bx
    push si
    xor ax, ax
    mov al, fileIndex
    mov bl, 13
    mul bl
    mov si, ax
    add si, OFFSET fileList
    mov baseLen, 0
    xor bx, bx
CopiarBaseArchivo:
    mov al, [si]
    cmp al, '.'
    je  FinBaseArchivo
    or  al, al
    je  FinBaseArchivo
    cmp bl, 8
    jae FinBaseArchivo
    mov baseName[bx], al
    inc bx
    inc si
    jmp CopiarBaseArchivo
FinBaseArchivo:
    mov baseLen, bl
    call ConstruirRutas
    pop si
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
    mov al, textBuffer[di]
    cmp al, ' '
    je  CeldaVacia
    mov bl, attrBuffer[di]
    mov dh, cursorRow
    mov dl, cursorCol
    call DibujarGlifoFondo
CeldaVacia:
    inc di
    inc cursorCol
    cmp cursorCol, EDIT_COLS
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

; TAB+I: Nyan Cat de 50x48 aproximadamente, dibujado directamente en A000h.
; No usa el cursor de texto ni BIOS, asi que no bloquea la pantalla VGA.
DibujarNyanVGA PROC NEAR
    ; arcoiris
    mov ax, 96
    mov bx, 92
    mov cx, 38
    mov dx, 3
    mov si, 12
    call PintarRectVGA
    mov bx, 95
    mov si, 14
    call PintarRectVGA
    mov bx, 98
    mov si, 10
    call PintarRectVGA
    mov bx, 101
    mov si, 11
    call PintarRectVGA
    ; cuerpo de galleta rosa (borde y relleno)
    mov ax, 132
    mov bx, 82
    mov cx, 28
    mov dx, 22
    mov si, 0
    call PintarRectVGA
    mov ax, 134
    mov bx, 84
    mov cx, 24
    mov dx, 18
    mov si, 13
    call PintarRectVGA
    mov ax, 137
    mov bx, 87
    mov cx, 3
    mov dx, 3
    mov si, 15
    call PintarRectVGA
    mov ax, 149
    mov bx, 95
    mov cx, 3
    mov dx, 3
    mov si, 15
    call PintarRectVGA
    ; cara del gato y orejas
    mov ax, 158
    mov bx, 78
    mov cx, 17
    mov dx, 4
    mov si, 0
    call PintarRectVGA
    mov ax, 160
    mov bx, 76
    mov cx, 4
    mov dx, 4
    mov si, 0
    call PintarRectVGA
    mov ax, 187
    mov bx, 76
    mov cx, 4
    mov dx, 4
    mov si, 0
    call PintarRectVGA
    mov ax, 158
    mov bx, 81
    mov cx, 24
    mov dx, 21
    mov si, 0
    call PintarRectVGA
    mov ax, 160
    mov bx, 82
    mov cx, 20
    mov dx, 18
    mov si, 7
    call PintarRectVGA
    mov ax, 164
    mov bx, 87
    mov cx, 3
    mov dx, 3
    mov si, 0
    call PintarRectVGA
    mov ax, 176
    mov bx, 87
    mov cx, 3
    mov dx, 3
    mov si, 0
    call PintarRectVGA
    mov ax, 170
    mov bx, 95
    mov cx, 4
    mov dx, 2
    mov si, 0
    call PintarRectVGA
    ret
DibujarNyanVGA ENDP

; TAB+J: totem pixel-art de 50x48, segundo sprite independiente.
DibujarTotemVGA PROC NEAR
    mov ax, 134
    mov bx, 74
    mov cx, 50
    mov dx, 48
    mov si, 6
    call PintarRectVGA
    mov ax, 137
    mov bx, 77
    mov cx, 44
    mov dx, 42
    mov si, 4
    call PintarRectVGA
    ; franjas y mascara
    mov ax, 137
    mov bx, 85
    mov cx, 44
    mov dx, 4
    mov si, 14
    call PintarRectVGA
    mov ax, 137
    mov bx, 101
    mov cx, 44
    mov dx, 4
    mov si, 12
    call PintarRectVGA
    mov ax, 145
    mov bx, 87
    mov cx, 28
    mov dx, 13
    mov si, 0
    call PintarRectVGA
    mov ax, 148
    mov bx, 89
    mov cx, 9
    mov dx, 6
    mov si, 15
    call PintarRectVGA
    mov ax, 166
    mov bx, 89
    mov cx, 9
    mov dx, 6
    mov si, 15
    call PintarRectVGA
    mov ax, 151
    mov bx, 91
    mov cx, 3
    mov dx, 3
    mov si, 0
    call PintarRectVGA
    mov ax, 170
    mov bx, 91
    mov cx, 3
    mov dx, 3
    mov si, 0
    call PintarRectVGA
    mov ax, 160
    mov bx, 96
    mov cx, 12
    mov dx, 2
    mov si, 12
    call PintarRectVGA
    mov ax, 151
    mov bx, 108
    mov cx, 12
    mov dx, 5
    mov si, 10
    call PintarRectVGA
    mov ax, 164
    mov bx, 108
    mov cx, 12
    mov dx, 5
    mov si, 10
    call PintarRectVGA
    ret
DibujarTotemVGA ENDP

; AX=X, BX=Y, CX=ancho, DX=alto, SI=color.  Rectangulo solido en 320x200.
PintarRectVGA PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    push bp
    mov bp, dx
    mov di, ax
    mov ax, bx
    mov bx, 320
    mul bx
    add ax, di
    mov di, ax
    mov ax, 0A000h
    mov es, ax
RectFilaVGA:
    push cx
    mov ax, si
    rep stosb
    pop cx
    mov ax, 320
    sub ax, cx
    add di, ax
    dec bp
    jnz RectFilaVGA
    pop bp
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PintarRectVGA ENDP

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
    cmp cursorCol, EDIT_COLS-5
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
    mov attrBuffer[di], 255
    cmp al, ' '
    je  PixelImagenVacio
    mov dh, cursorRow
    mov dl, cursorCol
    mov bl, 255
    call DibujarGlifoFondo
PixelImagenVacio:
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
    mov ax, 0013h
    int 10h
    call TemaMenuVGA
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
    mov ax, 0013h
    int 10h
    call DibujarEditor
    ret
MostrarAyuda ENDP

; Solicita dos palabras con la entrada DOS y redibuja el documento al terminar.
BuscarReemplazar PROC NEAR
    mov ax, 0013h
    int 10h
    call TemaMenuVGA
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
    mov ax, 0013h
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
    mov dh, cursorRow
    mov dl, cursorCol
    mov bl, currentAttr
    call DibujarGlifoFondo
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
    cmp cursorCol, EDIT_COLS-1
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

; Muestra un marco fino en la celda activa para que TAB+U/D/C sea visible.
DibujarCursorVGA PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    xor ax, ax
    mov al, cursorCol
    shl ax, 1
    shl ax, 1
    shl ax, 1
    xor bx, bx
    mov bl, cursorRow
    shl bx, 1
    shl bx, 1
    shl bx, 1
    mov cx, 8
    mov dx, 1
    mov si, 255
    call PintarRectVGA
    add bx, 7
    call PintarRectVGA
    sub bx, 7
    mov cx, 1
    mov dx, 6
    inc ax
    inc bx
    call PintarRectVGA
    add ax, 6
    call PintarRectVGA
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DibujarCursorVGA ENDP

ColocarCursor PROC NEAR
    ; En modo 13h no existe cursor de texto de hardware.
    ; El proximo caracter se dibuja en cursorRow/cursorCol.
    ret
ColocarCursor ENDP

; En modo 13h las entradas DOS se muestran en el punto que dibuja la interfaz.
ColocarCursorDirecto PROC NEAR
    mov ah, 02h
    mov bh, 0
    int 10h
    ret
ColocarCursorDirecto ENDP

; Entrada: DH=fila, DL=columna, DS:SI=cadena terminada en 0, BL=color 0..255.
; Dibuja caracteres de 8x8 directamente en A000h; no usa texto BIOS en modo 13h.
ImprimirCadena PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push bp
    push di
    push es
    push si
SiguienteLetraVGA:
    lodsb
    or  al, al
    jz  FinCadenaVGA
    call DibujarGlifoFondo        ; los espacios ya repintan el fondo correcto
    inc dl
    cmp dl, EDIT_COLS
    jb  SiguienteLetraVGA
FinCadenaVGA:
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

; Obtiene el puntero ROM de la fuente 8x8 (BH=3) y lo guarda en fontSeg/fontOff.
; Se llama una vez al entrar al editor; el puntero no cambia entre modos.
ObtenerFuente PROC NEAR
    push ax
    push bx
    push es
    push bp
    mov ax, 1130h
    mov bh, 3
    int 10h
    mov fontSeg, es
    mov fontOff, bp
    pop bp
    pop es
    pop bx
    pop ax
    ret
ObtenerFuente ENDP

; AL=ASCII, DH=fila, DL=columna, BL=color de letra (0..255).
; Dibuja el glifo pixel por pixel usando currentBackColor como fondo real,
; a diferencia de DibujarGlifoVGA (BIOS), que siempre pinta el fondo de negro.
DibujarGlifoFondo PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    ; --- copiar los 8 bytes del glifo a glyphBuf usando ES=fontSeg ---
    push bx
    xor ah, ah
    mov cl, 8
    mul cl                        ; ax = caracter*8
    mov si, ax
    add si, fontOff
    mov bx, fontSeg
    push es
    mov es, bx
    mov di, OFFSET glyphBuf
    mov cx, 8
CopiarGlifoFondo:
    mov al, es:[si]
    mov [di], al
    inc si
    inc di
    loop CopiarGlifoFondo
    pop es
    pop bx                        ; color de letra de vuelta en BL

    ; --- que pixeles de la celda caen dentro del panel horizontalmente ---
    mov maskFondo, 0FFh
    cmp dl, 0
    jne NoBordeIzq
    mov maskFondo, 0Fh            ; en la columna 0 los 4 primeros son borde
NoBordeIzq:
    cmp dl, EDIT_COLS-1
    jne NoBordeDer
    mov maskFondo, 0F0h           ; en la ultima columna los 4 ultimos son borde
NoBordeDer:

    ; --- calcular offset de pixel superior-izquierdo en DI ---
    ; OJO: "mul bx" (multiplicacion de 16 bits) siempre escribe en DX,
    ; asi que hay que leer DL (columna) ANTES de usarlo, o se pierde.
    push bx
    push bp
    xor ax, ax
    mov al, dl
    mov cl, 8
    mul cl                        ; ax = columna*8 (mul de 8 bits: no toca dx)
    mov bp, ax                    ; guardar offset de columna
    xor ax, ax
    mov al, dh
    mov cl, 8
    mul cl                        ; ax = fila*8
    mov yGlifo, ax                ; primera linea de pixeles de la celda
    mov bx, 320
    mul bx                        ; ax = (fila*8)*320 (mul de 16 bits: destruye dx aqui)
    add ax, bp
    mov di, ax
    pop bp
    pop bx                        ; color de letra otra vez en BL

    mov ax, 0A000h
    mov es, ax
    mov si, OFFSET glyphBuf
    mov dx, 8                     ; 8 filas del glifo
FilaGlifoFondo:
    push di
    mov ax, yGlifo                ; esta linea cae dentro del panel?
    cmp ax, PANEL_TOP
    jb  FilaFueraPanel
    cmp ax, PANEL_BOTTOM
    ja  FilaFueraPanel
    mov filaDentro, 1
    jmp FilaPanelLista
FilaFueraPanel:
    mov filaDentro, 0
FilaPanelLista:
    lodsb
    mov ah, 80h                   ; mascara de bit inicial
    mov cx, 8
ColGlifoFondo:
    test al, ah
    jz  PixelDeFondo
    mov es:[di], bl
    jmp SigPixelFondo
PixelDeFondo:
    push ax
    xor al, al                    ; por defecto, el azul oscuro del borde
    cmp filaDentro, 0
    je  PintarPixelFondo
    test maskFondo, ah
    jz  PintarPixelFondo
    mov al, currentBackColor
PintarPixelFondo:
    mov es:[di], al
    pop ax
SigPixelFondo:
    inc di
    shr ah, 1
    loop ColGlifoFondo
    pop di
    add di, 320
    inc yGlifo
    dec dx
    jnz FilaGlifoFondo

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DibujarGlifoFondo ENDP

END main
