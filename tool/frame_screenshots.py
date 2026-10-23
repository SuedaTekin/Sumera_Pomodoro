"""Frames raw app screenshots into Play Store images (1080x1920) with captions.

    $env:STORE_SHOTS=1; flutter test test/store_screenshots_test.dart
    python tool/frame_screenshots.py

Reads build/store_raw/<lang>_<n>.png, writes store/screenshots/<lang>/<n>.png.
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1080, 1920
TOP = (91, 77, 255)
BOTTOM = (22, 16, 60)
FONT_BOLD = 'C:/Windows/Fonts/segoeuib.ttf'
FONT = 'C:/Windows/Fonts/segoeui.ttf'

CAPTIONS = {
    'tr': [
        ('Odaklan, zaman aksın', 'Görevini seç, başlat; gerisini Sumera halletsin'),
        ('Her pomodoro bir yıldız', 'Günlerin kendi takımyıldızına dönüşür'),
        ('Ne kadar çalıştığını gör', 'Grafikler, seriler ve kişisel içgörüler'),
        ('Rozet kazan, serini koru', '14 rozetle motivasyonun hep yüksek'),
        ('Tam ekran odak', 'Dikkat dağıtmayan dev geri sayım'),
        ('Odak sesleri', 'Yağmur, okyanus ve renkli gürültüler'),
    ],
    'en': [
        ('Focus while time flows', 'Pick a task, press start, Sumera does the rest'),
        ('Every pomodoro is a star', 'Your days turn into constellations'),
        ('See how much you focus', 'Charts, streaks and personal insights'),
        ('Earn badges, keep your streak', '14 badges keep you motivated'),
        ('Full-screen focus', 'A huge, distraction-free countdown'),
        ('Focus sounds', 'Rain, ocean and colored noise'),
    ],
}


def background():
    g = Image.new('RGB', (1, 256))
    for y in range(256):
        t = y / 255
        g.putpixel((0, y), tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    bg = g.resize((W, H), Image.BICUBIC).convert('RGBA')
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([-300, -400, 900, 500], fill=(150, 130, 255, 90))
    return Image.alpha_composite(bg, glow.filter(ImageFilter.GaussianBlur(120)))


def fit_font(draw, text, path, size, max_w):
    while size > 20:
        font = ImageFont.truetype(path, size)
        if draw.textlength(text, font=font) <= max_w:
            return font
        size -= 2
    return ImageFont.truetype(path, size)


def frame(raw_path, title, subtitle, out_path):
    canvas = background()
    d = ImageDraw.Draw(canvas)
    tf = fit_font(d, title, FONT_BOLD, 76, W - 120)
    sf = fit_font(d, subtitle, FONT, 38, W - 140)
    d.text((W / 2, 150), title, font=tf, fill='white', anchor='mm')
    d.text((W / 2, 235), subtitle, font=sf, fill=(225, 222, 255), anchor='mm')

    shot = Image.open(raw_path).convert('RGBA')
    sw = 780
    sh = int(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], radius=52, fill=255)
    x, y = (W - sw) // 2, 330

    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x - 6, y + 14, x + sw + 6, y + sh + 24], radius=60, fill=(0, 0, 0, 150)
    )
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(28)))
    border = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle(
        [x - 10, y - 10, x + sw + 10, y + sh + 10], radius=62, fill=(255, 255, 255, 40)
    )
    canvas = Image.alpha_composite(canvas, border)
    canvas.paste(shot, (x, y), mask)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    canvas.convert('RGB').save(out_path, optimize=True)


for lang, captions in CAPTIONS.items():
    for n, (title, subtitle) in enumerate(captions, start=1):
        raw = f'build/store_raw/{lang}_{n}.png'
        frame(raw, title, subtitle, f'store/screenshots/{lang}/{n}.png')
print('done')
