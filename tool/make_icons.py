"""Sumera emblem v2: an abstract focus ring - a progress arc around a focus point."""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = sys.argv[1]
OUT_PREVIEW = sys.argv[2] if len(sys.argv) > 2 else None
SS = 4

TOP = (91, 77, 255)      # indigo
BOTTOM = (45, 31, 140)   # deep violet
ACCENT = (76, 201, 240)  # cyan
WHITE = (255, 255, 255)


def vgradient(size, c1, c2):
    g = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        g.putpixel((0, y), tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)))
    return g.resize((size, size), Image.BICUBIC)


def cap(d, cx, cy, rr, ang, w, fill):
    a = math.radians(ang)
    x, y = cx + rr * math.cos(a), cy + rr * math.sin(a)
    d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=fill)


def draw_mark(img, cx, cy, r, mono=False):
    """r = outer radius of the ring."""
    w = r * 0.22
    rr = r - w / 2
    box = [cx - r, cy - r, cx + r, cy + r]
    white = WHITE + (255,)

    if not mono:
        track = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(track).ellipse(box, outline=(255, 255, 255, 55), width=int(w))
        img.alpha_composite(track)

    d = ImageDraw.Draw(img)
    # 285-degree progress arc, starting at 12 o'clock, clockwise.
    start, end = -90, 195
    d.arc(box, start, end, fill=white, width=int(w))
    cap(d, cx, cy, rr, start, w, white)
    cap(d, cx, cy, rr, end, w, white)

    # Leading point of the arc ("now"), accent colored.
    dot = ACCENT + (255,) if not mono else white
    cap(d, cx, cy, rr, end, w * 1.55, dot)
    if not mono:
        cap(d, cx, cy, rr, end, w * 0.55, white)

    # Focus point in the center.
    fr = r * 0.26
    d.ellipse([cx - fr, cy - fr, cx + fr, cy + fr], fill=white)


def emblem(size, rounded=True, background=True, mark_scale=0.30):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if background:
        bg = vgradient(S, TOP, BOTTOM).convert("RGBA")
        # Soft light from the top-left.
        glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse([-S * 0.3, -S * 0.4, S * 0.8, S * 0.6], fill=(140, 120, 255, 110))
        glow = glow.filter(ImageFilter.GaussianBlur(S * 0.12))
        bg = Image.alpha_composite(bg, glow)
        mask = Image.new("L", (S, S), 0)
        if rounded:
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.225), fill=255)
        else:
            mask.paste(255, [0, 0, S, S])
        img.paste(bg, (0, 0), mask)
    draw_mark(img, S / 2, S / 2, S * mark_scale)
    return img.resize((size, size), Image.LANCZOS)


def mono(size):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_mark(img, S / 2, S / 2, S * 0.42, mono=True)
    return img.resize((size, size), Image.LANCZOS)


def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def size_of(path):
    with Image.open(path) as im:
        return im.size[0]


master = emblem(1024)
if OUT_PREVIEW:
    master.save(OUT_PREVIEW)
    sys.exit(0)

save(master, "assets/branding/emblem.png")
save(emblem(512, rounded=False).convert("RGB"), "store/icon-512.png")

res = "android/app/src/main/res"
for dpi, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    save(master.resize((px, px), Image.LANCZOS), f"{res}/mipmap-{dpi}/ic_launcher.png")
    save(emblem(px * 108 // 48, background=False, mark_scale=0.22), f"{res}/mipmap-{dpi}/ic_launcher_foreground.png")
    save(mono(px // 2), f"{res}/drawable-{dpi}/ic_stat_pomodoro.png")
    # Splash logo (Android 12+ splash uses a 288dp canvas; legacy splash centers it).
    save(emblem(px * 2, background=False, mark_scale=0.30), f"{res}/drawable-{dpi}/splash_logo.png")

ios = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
square = emblem(1024, rounded=False).convert("RGB")
for name in os.listdir(os.path.join(ROOT, ios)):
    if name.endswith(".png"):
        w = size_of(os.path.join(ROOT, ios, name))
        save(square.resize((w, w), Image.LANCZOS), f"{ios}/{name}")

save(master.resize((32, 32), Image.LANCZOS), "web/favicon.png")
for name in os.listdir(os.path.join(ROOT, "web/icons")):
    w = size_of(os.path.join(ROOT, "web/icons", name))
    save((square if "maskable" in name else master).resize((w, w), Image.LANCZOS), f"web/icons/{name}")

master.save(os.path.join(ROOT, "windows/runner/resources/app_icon.ico"),
            sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

mac = "macos/Runner/Assets.xcassets/AppIcon.appiconset"
for name in os.listdir(os.path.join(ROOT, mac)):
    if name.endswith(".png"):
        w = size_of(os.path.join(ROOT, mac, name))
        save(master.resize((w, w), Image.LANCZOS), f"{mac}/{name}")

# Play Store feature graphic (1024x500).
FW, FH = 1024, 500
fg = vgradient(FW * 2, TOP, BOTTOM).resize((FW, FH))
fg = fg.convert("RGBA")
glow = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([-200, -300, 600, 400], fill=(140, 120, 255, 120))
fg = Image.alpha_composite(fg, glow.filter(ImageFilter.GaussianBlur(90)))
mark = emblem(300, background=False, mark_scale=0.42)
fg.alpha_composite(mark, (60, (FH - 300) // 2))
from PIL import ImageFont
d = ImageDraw.Draw(fg)
x, max_w = 400, FW - 400 - 56
size = 64
while True:
    bold = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", size)
    if d.textlength("Sumera Pomodoro", font=bold) <= max_w:
        break
    size -= 2
reg = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", int(size * 0.5))
d.text((x, 250), "Sumera Pomodoro", font=bold, fill=(255, 255, 255), anchor="ls")
d.text((x, 300), "Odaklan. Dinlen. İlerlemeni gör.", font=reg, fill=(225, 225, 255), anchor="ls")
save(fg.convert("RGB"), "store/feature-graphic.png")
print("done")
