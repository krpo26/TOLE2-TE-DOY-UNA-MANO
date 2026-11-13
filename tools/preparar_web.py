#!/usr/bin/env python3
"""Ajusta título, idioma y nombre de la página web generada por `flutter create`."""
import json
import pathlib
import re

p = pathlib.Path('web/index.html')
h = p.read_text()
h = re.sub(r'<title>.*?</title>', '<title>TE DOY UNA MANO!</title>', h, flags=re.S)
h = re.sub(r'(<meta name="description" content=")[^"]*(")',
           r'\1Encontrá profesionales de oficios y pedí presupuestos\2', h)
h = h.replace('<html>', '<html lang="es">', 1)
p.write_text(h)

m = pathlib.Path('web/manifest.json')
if m.exists():
    d = json.loads(m.read_text())
    d['name'] = 'TE DOY UNA MANO!'
    d['short_name'] = 'TE DOY UNA MANO!'
    m.write_text(json.dumps(d, indent=2, ensure_ascii=False))
print('OK web')
