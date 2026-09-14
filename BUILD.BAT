@echo off
rem Ensambla y enlaza el menu con el editor en un solo EDITOR.EXE
rem Requiere TASM.EXE y LINK.EXE en el PATH (C: en el dosbox del curso).
tasm menu.asm; > TASM1.LOG
tasm editor.asm; > TASM2.LOG
link menu+editor,EDITOR.EXE,NUL; > LINK.LOG
