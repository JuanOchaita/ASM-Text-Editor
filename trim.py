import argparse
from pathlib import Path

from PIL import Image

"""python trim.py imagen.png 0 0 11 18 mouse.png"""

parser = argparse.ArgumentParser()
parser.add_argument("imagen")
parser.add_argument("x1", type=int)
parser.add_argument("y1", type=int)
parser.add_argument("x2", type=int)
parser.add_argument("y2", type=int)
parser.add_argument("salida")
args = parser.parse_args()

if not (0 <= args.x1 <= args.x2 < 320 and 0 <= args.y1 <= args.y2 < 200):
    raise SystemExit("El rango debe estar dentro de x=0..319 e y=0..199")

with Image.open(args.imagen) as imagen:
    if imagen.size != (320, 200):
        raise SystemExit(f"La imagen debe medir 320x200 píxeles, no {imagen.size[0]}x{imagen.size[1]}")
    recorte = imagen.crop((args.x1, args.y1, args.x2 + 1, args.y2 + 1))
    recorte.save(Path(args.salida))
