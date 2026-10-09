#!/usr/bin/env python3
"""Uygulama ikonlarını ve Google Play mağaza görsellerini üretir.

Çıktılar:
  assets/icons/        oyun içinde kullanılan ikonlar (Godot export ayarı bunlara bakar)
  store/icons/         Play Console için 512x512 ikon
  store/graphics/      1024x500 öne çıkan görsel

Kullanım:  python3 tools/make_store_assets.py
Gereksinim: Pillow
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
SS = 4  # süper örnekleme: kenarlar yumuşak çıksın

C_BG_TOP = (11, 7, 32)
C_BG_BOT = (42, 15, 77)
C_CYAN = (0, 240, 255)
C_PINK = (255, 43, 214)
C_GREEN = (57, 255, 136)
C_RED = (255, 56, 96)


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(int(C_BG_TOP[i] + (C_BG_BOT[i] - C_BG_TOP[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def add_grid(img, step, ground_y=None):
    d = ImageDraw.Draw(img, "RGBA")
    w, h = img.size
    for x in range(0, w, step):
        d.line([(x, 0), (x, h)], fill=(140, 77, 255, 34), width=max(1, step // 64))
    y = ground_y if ground_y is not None else h
    while y > 0:
        d.line([(0, y), (w, y)], fill=(140, 77, 255, 34), width=max(1, step // 64))
        y -= step
    return img


def glow(layer, radius, passes=2, boost=1.0):
    """Katmanın parlak (neon) halesini üretip üzerine ekler."""
    base = layer
    for _ in range(passes):
        blur = layer.filter(ImageFilter.GaussianBlur(radius))
        r, g, b, a = blur.split()
        a = a.point(lambda v: min(255, int(v * boost)))
        blur = Image.merge("RGBA", (r, g, b, a))
        base = Image.alpha_composite(blur, base)
    return base


def poly_outline(d, pts, color, width):
    d.line(pts + [pts[0], pts[1]], fill=color, width=width, joint="curve")


def cube_layer(size, cx, cy, side, angle_deg, line):
    """Neon yeşil küp (oyundaki oyuncunun aynısı: koyu dolgu, dış ve iç çerçeve)."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    a = math.radians(angle_deg)

    def pts(half):
        out = []
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            x, y = sx * half, sy * half
            out.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
        return out

    d.polygon(pts(side / 2), fill=(C_GREEN[0] // 4, C_GREEN[1] // 4, C_GREEN[2] // 4, 255))
    poly_outline(d, pts(side / 2), C_GREEN + (255,), line)
    poly_outline(d, pts(side * 0.225), C_GREEN + (255,), max(1, int(line * 0.75)))
    return layer


def spike_layer(size, x, base_y, w, h, line):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pts = [(x - w / 2, base_y), (x, base_y - h), (x + w / 2, base_y)]
    d.polygon(pts, fill=(int(C_RED[0] * 0.45), int(C_RED[1] * 0.45), int(C_RED[2] * 0.45), 255))
    d.line(pts + [pts[0], pts[1]], fill=C_RED + (255,), width=line, joint="curve")
    return layer


def ground_layer(size, y, line):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).line([(0, y), (size[0], y)], fill=C_CYAN + (255,), width=line)
    return layer


def hero(size, content_scale=1.0, with_bg=True, ground=True):
    """Ikonun ana sahnesi: zeminde sivri engel, üstünden zıplayan küp."""
    S = size[0] * SS
    big = (S, S)
    cx0 = S / 2
    k = content_scale
    ln = max(2, int(S * 0.018 * k))
    ground_y = S * (0.5 + 0.24 * k)
    if with_bg:
        img = gradient(S, S).convert("RGBA")
        add_grid(img, S // 8, int(ground_y))
        # Pembe "nabız" halesi
        halo = Image.new("RGBA", big, (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse([S * 0.1, S * 0.12, S * 0.9, S * 0.92], fill=C_PINK + (46,))
        img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(S * 0.07)))
    else:
        img = Image.new("RGBA", big, (0, 0, 0, 0))
    scene = Image.new("RGBA", big, (0, 0, 0, 0))
    if ground:
        scene = Image.alpha_composite(scene, ground_layer(big, int(ground_y), ln))
    sp_w, sp_h = S * 0.20 * k, S * 0.22 * k
    scene = Image.alpha_composite(scene, spike_layer(big, cx0 + S * 0.17 * k, ground_y, sp_w, sp_h, ln))
    scene = Image.alpha_composite(scene, cube_layer(big, cx0 - S * 0.12 * k, ground_y - S * 0.27 * k, S * 0.25 * k, -16, ln))
    scene = glow(scene, S * 0.012 * k, passes=2, boost=1.4)
    out = Image.alpha_composite(img, scene)
    return out.resize(size, Image.LANCZOS)


def monochrome(size):
    S = size[0] * SS
    big = (S, S)
    ln = int(S * 0.018 * 0.62)
    k = 0.62
    ground_y = S * (0.5 + 0.24 * k)
    layer = Image.new("RGBA", big, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.line([(S * 0.24, ground_y), (S * 0.76, ground_y)], fill=(255, 255, 255, 255), width=ln)
    sp = spike_layer(big, S / 2 + S * 0.17 * k, ground_y, S * 0.20 * k, S * 0.22 * k, ln)
    cube = cube_layer(big, S / 2 - S * 0.12 * k, ground_y - S * 0.27 * k, S * 0.25 * k, -16, ln)
    for part in (sp, cube):
        a = part.split()[3].point(lambda v: 255 if v > 8 else 0)
        layer.paste(Image.new("RGBA", big, (255, 255, 255, 255)), (0, 0), a)
    return layer.resize(size, Image.LANCZOS)


def title_font(px):
    f = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "Orbitron.ttf"), px)
    try:
        f.set_variation_by_axes([900])
    except Exception:
        pass
    return f


def spaced_text(d, xy, text, font, fill, spacing):
    x, y = xy
    for ch in text:
        d.text((x, y), ch, font=font, fill=fill)
        x += d.textlength(ch, font=font) + spacing


def text_width(d, text, font, spacing):
    return sum(d.textlength(ch, font=font) + spacing for ch in text) - spacing


def feature_graphic():
    W, H = 1024, 500
    S = SS
    img = gradient(W * S, H * S).convert("RGBA")
    add_grid(img, 64 * S, 400 * S)
    scene = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(scene)
    ln = 3 * S
    d.line([(0, 400 * S), (W * S, 400 * S)], fill=C_CYAN + (255,), width=ln)
    for x in (120, 880, 944):
        scene = Image.alpha_composite(scene, spike_layer(img.size, x * S, 400 * S, 54 * S, 58 * S, ln))
    scene = Image.alpha_composite(scene, cube_layer(img.size, 190 * S, 315 * S, 100 * S, -14, ln))
    scene = Image.alpha_composite(scene, cube_layer(img.size, 790 * S, 355 * S, 64 * S, 12, ln))
    d = ImageDraw.Draw(scene)
    font = title_font(112 * S)
    sp = 12 * S
    gap = 34 * S
    w1 = text_width(d, "NEON", font, sp)
    w2 = text_width(d, "PULSE", font, sp)
    x0 = (W * S - (w1 + gap + w2)) / 2
    spaced_text(d, (x0, 125 * S), "NEON", font, C_CYAN + (255,), sp)
    spaced_text(d, (x0 + w1 + gap, 125 * S), "PULSE", font, C_PINK + (255,), sp)
    scene = glow(scene, 7 * S, passes=2, boost=1.3)
    out = Image.alpha_composite(img, scene).resize((W, H), Image.LANCZOS).convert("RGB")
    return out


def main():
    icons = os.path.join(ROOT, "assets", "icons")
    for p in (icons, os.path.join(ROOT, "store", "icons"), os.path.join(ROOT, "store", "graphics")):
        os.makedirs(p, exist_ok=True)

    full = hero((512, 512)).convert("RGBA")
    full.save(os.path.join(ROOT, "store", "icons", "icon-512.png"))
    full.resize((192, 192), Image.LANCZOS).save(os.path.join(icons, "icon-192.png"))
    full.resize((256, 256), Image.LANCZOS).save(os.path.join(icons, "icon-256.png"))
    # Adaptif ikon katmanları (Android: 432x432, güvenli alan ortadaki ~264 px)
    hero((432, 432), content_scale=0.62, with_bg=False).save(os.path.join(icons, "adaptive-foreground.png"))
    hero((432, 432), content_scale=1.0, with_bg=True, ground=False)  # sadece deneme amaçlı üretilmez
    bg = gradient(432 * SS, 432 * SS).convert("RGBA")
    add_grid(bg, 54 * SS, 335 * SS)
    halo = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([45 * SS, 55 * SS, 387 * SS, 397 * SS], fill=C_PINK + (46,))
    bg = Image.alpha_composite(bg, halo.filter(ImageFilter.GaussianBlur(30 * SS)))
    bg.resize((432, 432), Image.LANCZOS).convert("RGB").save(os.path.join(icons, "adaptive-background.png"))
    monochrome((432, 432)).save(os.path.join(icons, "adaptive-monochrome.png"))
    feature_graphic().save(os.path.join(ROOT, "store", "graphics", "feature-graphic-1024x500.png"))
    print("görseller üretildi")


if __name__ == "__main__":
    main()
