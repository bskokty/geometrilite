#!/usr/bin/env python3
"""Google Play için indirilebilir görsel/metin paketini üretir: store/neon-pulse-store-assets.zip

Önce şunları çalıştır: tools/make_store_assets.py ve (ekran görüntüleri için) tools/capture_screenshots.gd
"""
import glob
import os
import zipfile

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "store", "neon-pulse-store-assets.zip")

FILES = [
    ("store/icons/icon-512.png", "1-icon/icon-512.png"),
    ("assets/icons/adaptive-foreground.png", "1-icon/android-adaptive/foreground-432.png"),
    ("assets/icons/adaptive-background.png", "1-icon/android-adaptive/background-432.png"),
    ("assets/icons/adaptive-monochrome.png", "1-icon/android-adaptive/monochrome-432.png"),
    ("store/graphics/feature-graphic-1024x500.png", "2-feature-graphic/feature-graphic-1024x500.png"),
    ("store/listing.md", "4-listing/listing.md"),
    ("store/play-console-alanlar.md", "4-listing/play-console-alanlar.md"),
    ("docs/privacy-policy.md", "5-privacy/privacy-policy.md"),
    ("public/privacy/index.html", "5-privacy/privacy-policy.html"),
]
README = """Neon Pulse - Google Play paketi
================================
1-icon/              512x512 uygulama ikonu (Play Console > Ana mağaza girişi > Uygulama simgesi).
                     android-adaptive/ klasörü AAB içine zaten gömülüdür; bilgi amaçlıdır.
2-feature-graphic/   1024x500 öne çıkan grafik.
3-screenshots/       1920x1080 yatay telefon ekran görüntüleri (Play en az 2, en fazla 8 kabul eder).
4-listing/           Başlık, kısa/tam açıklama (EN, TR) ve Play Console form önerileri.
5-privacy/           Gizlilik politikası metni. Yayında: https://geometrilite.vercel.app/privacy
"""


def main():
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("README.txt", README)
        for src, dst in FILES:
            z.write(os.path.join(ROOT, src), dst)
        for shot in sorted(glob.glob(os.path.join(ROOT, "store", "screenshots", "*.png"))):
            z.write(shot, "3-screenshots/" + os.path.basename(shot))
    print("yazıldı:", os.path.normpath(OUT), round(os.path.getsize(OUT) / 1024), "KB")


if __name__ == "__main__":
    main()
