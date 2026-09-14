# ASM-Text-Editor

Aplicación en assembler x8086 que emula las capacidades básicas de un editor de texto.
Crear, editar y guardar archivos de texto. Cada archivo guarda el color de fondo elegido,
el texto ingresado, el color de cada carácter y las imágenes que el usuario haya insertado.

## Estructura

El programa es un solo ejecutable (`EDITOR.EXE`) formado por dos módulos:

- `Menu.asm` — punto de entrada. Escritorio con mouse: lista los documentos (`*.HTM`),
  icono `+` para crear uno nuevo, ventana `File` con **Edit** / **Delete**, búsqueda e
  icono de salir.
- `editor.asm` — pantalla de edición. No tiene `main`: el menú entra por
  `AbrirEditorNuevo` (documento en blanco) o `AbrirEditorConArchivo` (DS:SI = nombre).

## Compilar

Con TASM y LINK en el PATH (el DOSBox del curso), desde la carpeta del proyecto:

```
BUILD.BAT
```

que equivale a:

```
tasm menu.asm;
tasm editor.asm;
link menu+editor,EDITOR.EXE,NUL;
```

## Flujo

1. El menú lista los `*.HTM` de la carpeta del programa (un documento = `NOMBRE.HTM` +
   `NOMBRE.TXT` + `NOMBRE.EDT`).
2. Clic en `+` → entra al editor en blanco, **sin pedir nombre** (como Word).
3. Clic en un archivo → ventana `File` → **Edit** abre el documento, **Delete** borra sus
   tres archivos.
4. `TAB+F` en el menú busca un documento por nombre y lo abre si existe.
5. En el editor, `TAB+S` guarda: pide el nombre en la línea inferior solo si el documento
   es nuevo; después guarda directo.
6. `TAB+Z` (también `TAB+R` o `ESC`) regresa al menú.

## Atajos del editor

| Atajo | Acción |
|-------|--------|
| `TAB+S` | Guardar (`.TXT`, `.HTM` y `.EDT`) |
| `TAB+Z` | Regresar al menú |
| `TAB+H` | Ayuda |
| `TAB+M` / `TAB+N` | Color de letra / color de fondo |
| `TAB+I` / `TAB+J` | Insertar imagen 1 / 2 |
| `TAB+B` | Buscar y reemplazar |
| `TAB+C`, `TAB+U`, `TAB+D` | Centrar, primer renglón, último renglón |
| `TAB+O` | Navegador de archivos `.EDT` |

## Formatos

- `.TXT` — texto plano, 19 renglones de 40 columnas.
- `.HTM` — export con el fondo y el color real de cada letra, leídos del DAC de la VGA.
- `.EDT` — formato propio: cabecera (fondo, color, ancho, alto) + texto + colores +
  copia de la pantalla (para conservar las imágenes insertadas).

Los `.EDT` se guardan en la carpeta del programa; si existe `D:` se usa como respaldo.
