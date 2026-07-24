import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = r"C:\Users\danie\google play\crypto_miner_tycoon\assets\icon"
os.makedirs(OUT, exist_ok=True)

S = 1024
DARK = (26, 29, 33, 255)      # #1A1D21
AMBER = (255, 183, 0, 255)    # #FFB700
GLYPH = "₿"              # Bitcoin sign

# Fonts confirmed (via fontTools) to contain U+20BF, best-looking first.
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\calibrib.ttf",
    r"C:\Windows\Fonts\consolab.ttf",
]


def has_glyph(path, ch):
    try:
        from fontTools.ttLib import TTFont
        f = TTFont(path)
        return any(ord(ch) in t.cmap for t in f["cmap"].tables)
    except Exception:
        return None


def pick_font(size):
    for p in FONT_CANDIDATES:
        if os.path.exists(p) and has_glyph(p, GLYPH):
            return ImageFont.truetype(p, size), p
    raise RuntimeError("no font with U+20BF found")


def draw_glyph(base, cx, cy, size, color):
    font, path = pick_font(size)
    d = ImageDraw.Draw(base)
    bbox = d.textbbox((0, 0), GLYPH, font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((cx - w / 2 - bbox[0], cy - h / 2 - bbox[1]), GLYPH, font=font, fill=color)
    return path


def amber_glow(cx, cy, r, alpha=130, blur=55):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(
        (cx - r, cy - r, cx + r, cy + r), fill=(255, 183, 0, alpha)
    )
    return layer.filter(ImageFilter.GaussianBlur(blur))


def ring(img, cx, cy, r, width, color):
    ImageDraw.Draw(img).ellipse(
        (cx - r, cy - r, cx + r, cy + r), outline=color, width=width
    )


def make_full(path):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle((0, 0, S, S), radius=200, fill=DARK)
    cx = cy = S // 2
    r = 360
    img.alpha_composite(amber_glow(cx, cy, r - 30, alpha=90, blur=70))  # soft halo
    ring(img, cx, cy, r, 26, AMBER)
    fpath = draw_glyph(img, cx, cy - 8, 560, AMBER)
    img.save(path)
    return fpath


def make_fg(path):
    # Transparent foreground for adaptive icons; mark kept inside the central
    # safe zone (~62%) so the launcher mask never clips it.
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = cy = S // 2
    r = 300
    img.alpha_composite(amber_glow(cx, cy, r - 20, alpha=80, blur=55))
    ring(img, cx, cy, r, 22, AMBER)
    draw_glyph(img, cx, cy - 6, 460, AMBER)
    img.save(path)


fpath = make_full(os.path.join(OUT, "app_icon.png"))
make_fg(os.path.join(OUT, "app_icon_fg.png"))
print("font used:", fpath)
print("wrote app_icon.png + app_icon_fg.png to", OUT)
