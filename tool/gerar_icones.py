"""Gera favicon e ícones PWA (Icons.archive em verde IFSul).

Uso (dentro do container Flutter, a partir de /app):
  apt-get install -y python3-pil && python3 tool/gerar_icones.py
"""
from PIL import Image, ImageDraw, ImageFont

FONTE = "/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
ARCHIVE = chr(0xE091)
VERDE = (0, 122, 51, 255)
BRANCO = (255, 255, 255, 255)


def gerar(tamanho, maskable):
    escala = 4
    lado = tamanho * escala
    img = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if maskable:
        draw.rectangle([0, 0, lado, lado], fill=VERDE)
        glifo = 0.5
    else:
        draw.rounded_rectangle([0, 0, lado - 1, lado - 1], radius=lado // 5, fill=VERDE)
        glifo = 0.68
    fonte = ImageFont.truetype(FONTE, int(lado * glifo))
    draw.text((lado / 2, lado / 2), ARCHIVE, font=fonte, fill=BRANCO, anchor="mm")
    return img.resize((tamanho, tamanho), Image.LANCZOS)


gerar(512, False).save("web/icons/Icon-512.png")
gerar(192, False).save("web/icons/Icon-192.png")
gerar(512, True).save("web/icons/Icon-maskable-512.png")
gerar(192, True).save("web/icons/Icon-maskable-192.png")
gerar(32, False).save("web/favicon.png")
