"""Makes Craftbound's textures in Media/ (TGA, power-of-two sizes) from the painted art.

Run from the addon folder:  python3 tools/make_media.py
Craftbound.png is painted by Marius (also the CurseForge picture and the docs logo).
"""
from PIL import Image, ImageDraw

OUT = "Media/"
ART = "Craftbound.png"


def emblem(size):
    """The art on transparency."""
    return Image.open(ART).convert("RGBA").resize((size, size), Image.LANCZOS)


def icon(size):
    """Square icon (addon list, minimap): the art on a dark walnut gradient."""
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    d = ImageDraw.Draw(bg)
    for y in range(size):
        t = y / size
        d.line([(0, y), (size, y)], fill=(int(28 + 34 * (1 - t)), int(18 + 22 * (1 - t)), int(10 + 12 * (1 - t)), 255))
    inset = max(1, size // 16)
    art = emblem(size * 2).resize((size - 2 * inset, size - 2 * inset), Image.LANCZOS)
    bg.alpha_composite(art, (inset, inset))
    return bg


def save(img, name):
    img.save(OUT + name + ".tga")
    print("wrote", OUT + name + ".tga", img.size)


if __name__ == "__main__":
    save(emblem(256), "Logo256")
    save(emblem(64), "Logo64")
    save(icon(64), "Icon64")
    save(icon(128), "Icon128")
