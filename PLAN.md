# Neon Pulse — Plan

Özgün bir mobil ritim-platform oyunu. Geometry Dash'in adı, ikonları, müzikleri ve görsel varlıkları kullanılmaz; görsel dil (neon/sentetik), seviyeler ve müzik özgündür.

## Teknoloji gerekçesi
- **Godot 4.3 (GDScript):** ücretsiz ve açık kaynak, lisans/royalty yok; Android + iOS export'u yerleşik; 2D hattı güçlü; küçük APK/IPA; `_draw()` ile vektör çizim tüm sahneyi koddan kurmayı kolaylaştırır.
- **Mobile renderer:** düşük donanımda yeterli, 2D için fazlasıyla hızlı.
- Unity/Unreal: bu ölçek için gereksiz ağır. Flutter/Flame: ses senkronu ve fizik adımı kontrolü daha zayıf.

## Mimari
- `project.godot`: 1280x720, yatay, `canvas_items` / `expand`, `emulate_mouse_from_touch` (tek girdi yolu: fare olayı).
- `scenes/game.tscn`: `Node2D` (game.gd) + `Camera2D "Camera"`. Geri kalan her şey (HUD CanvasLayer dahil) koddan kurulur.
- `scripts/game.gd`: seviye yükleme, sabit adımlı fizik (`_physics_process`), AABB çarpışma, çizim, HUD, durum makinesi (PLAYING / DEAD / WON).
- `levels/*.json`: `{name, speed, rows}`; `.` boş, `#` blok, `^` diken; son satır zemin seviyesi. Tile (c,r) → x=c·64, y=560−(satır−r)·64.
- `tools/gen_levels.py`: 6 seviyeyi üretir (hız 520 → 650, boşluklar daralır, segmentler zorlaşır) ve game.gd ile aynı fizik sabitleriyle simüle edip **geçilebilirliği doğrular** (fizik sabitleri değişirse yeniden çalıştırılmalı).
- Determinizm: sabit dt, rastgelelik yalnızca görsel parçacıklarda.

### Oynanış eklemeleri
- **Çift zıplama:** havada her yeni dokunuş yeni bir zıplama verir (sınırsız, arka arkaya basarak havada kalınabilir). Basılı tutmak havada zıplatmaz, yalnızca yerde her inişte tekrar zıplatır.
- **Kademeli zorluk:** `levels/level_01..06.json`, bitirince sonraki seviye açılır.
- **Yerel kayıt:** `user://save.json` (açılan seviye, seviye başına en iyi %, toplam deneme). Hesap/bulut girişi yok; bunun için sunucu (ör. Play Games / Game Center veya Supabase/Firebase) gerekir ve yol haritasındadır.

### Fizik özeti
T=64, GROUND_Y=560, g=4200, zıplama hızı −1100 (yaklaşık 4,25 tile menzil, 2,25 tile yükseklik), oyuncu 56x56, kamera oyuncunun 300 px önünde. Blok: üstten iniş (vy≥0 ve önceki alt kenar bloğun üstünün 12 px içinde) aksi halde ölüm. Diken: 0,55 genişlik / alt %60 yükseklik hitbox.

## Yol haritası
1. **Prototip (bu aşama):** çekirdek döngü, Level 1, HUD.
2. **Müzik senkronu:** zaman = `AudioStreamPlayer` oynatma konumu + çıkış gecikmesi (`AudioServer.get_output_latency`) + kullanıcı kalibrasyonu; konum = hız × zaman.
3. **Pratik modu / checkpoint.**
4. **Gemi modu, zıplama pedi, portallar.**
5. **Ana menü, seviye seçimi, kayıt** (`user://`).
6. **Performans ve mağaza hazırlığı:** draw-call/`_draw` önbellekleme, 120 Hz fizik enterpolasyonu, ikon/izin/export ayarları, gizlilik politikası.

## Gelir modeli
- Ücretsiz çekirdek (ilk seviyeler) + **ödüllü reklam** (devam et / ekstra kozmetik).
- Tek seferlik "Reklamsız + tüm seviyeler" satın alımı.
- Kozmetik paketleri (küp/iz efektleri), sezonluk seviye paketleri.
- Zorlayıcı/agresif reklam yok; çocuk politikalarına uyum.

## Riskler
- **Telif/marka benzerliği:** özgün isim, görsel ve müzik; markaya atıf yok.
- **Ses gecikmesi (Bluetooth/Android):** kalibrasyon ekranı şart.
- **Fizik tutarlılığı:** 60 Hz dışı ekranlarda enterpolasyon; fizik sabit adımda kalmalı.
- **Zorluk dengesi:** seviyeler simülatörle doğrulanır, ama insan oynanabilirliği (kısa pencereler, ör. üçlü diken) test edilmeli.
- **Mağaza kabulü:** gizlilik, reklam SDK'ları, yaş derecelendirmesi.
- **Godot mobil export'u:** imzalama (Android keystore, Apple sertifikası) ve iOS için Mac gerekliliği.
