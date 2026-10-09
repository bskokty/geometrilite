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
- `levels/segments.json`: doğrulanmış engel parçaları ve seviye profilleri (hız, havada zıplama, boşluk, ağırlıklar). Karakterler: `.` boş, `#` blok, `^` yer dikeni, `v` tavan dikeni; son satır zemin seviyesi. Tile (c,r) → x=c·64, y=560−(satır−r)·64.
- `tools/gen_segments.py`: 10 seviyeyi üretir (hız 420 → 675, boşluklar daralır, segmentler zorlaşır, tavan engelleri ve havada zıplama hakkı eklenir) ve game.gd ile aynı fizik sabitleriyle simüle edip **geçilebilirliği doğrular** (fizik sabitleri değişirse yeniden çalıştırılmalı).
- Determinizm: sabit dt, rastgelelik yalnızca görsel parçacıklarda.

### Oynanış
- **Sonsuz seviyeler:** Seviye sayısı sınırsızdır. Her seviye numarası, `levels/segments.json` içindeki doğrulanmış engel parçalarından numaraya bağlı tohumla kurulur (aynı numara hep aynı seviyeyi verir). İlk 12 seviyede hız 420 → 695 px/sn artar, parça havuzu zorlaşır; 12'den sonra hız sabit kalır, seviye uzar (en fazla +24 parça). Bitirince bir sonraki seviye otomatik başlar.
- **Giriş seviyesi** bilinçli olarak yavaş ve basittir (sabit dizilim, geniş boşluklar).
- **Havada zıplama (seviyeye bağlı):** Seviye 1-5'te yok; 6-7'de 1, 8'de 2, 9'da 3, 10 ve sonrasında sınırsız. Yeni dokunuş = ek zıplama; basılı tutmak havada zıplatmaz, yerde her inişte tekrar zıplatır. Yetenek açıldığı seviyenin başında kısa bir duyuru çıkar; 6+ seviyelerde yalnızca bu yetenekle geçilebilen uzun bloklar bulunur.
- **Tavan engelleri:** 4. seviyeden itibaren tavandan sarkan dikenler ve asılı bloklar; havada zıplama olan seviyelerde tavan çizgisi küpü sınırlar.
- **Sade HUD:** oyun içinde yalnızca seviye numarası, ilerleme çubuğu ve yüzde (+ ana ekrana dönüş düğmesi).
- **Ana ekran:** "Kaldığın yer" + seviye numarası + en iyi yüzde, Başla/Devam Et, Oyunu Sıfırla (iki dokunuşla onay) ve dil düğmesi. Oyuncu Başla'ya basmadan da nerede kaldığını görür.
- **Dil desteği:** EN, TR, DE, ES, FR, PT, IT, RU. Cihaz diliyle başlar, ana ekrandaki düğmeyle değişir ve kaydedilir. Metinler `STR` sözlüğündedir.
- **Yerel kayıt:** `user://save.json` (kalınan seviye, seviye başına en iyi %, toplam deneme, dil). **Karar: kullanıcı kaydı/hesap yok.** İlerleme yalnızca cihazda tutulur (sunucu, giriş ve kişisel veri yok; gizlilik ve mağaza süreci basitleşir). Cihaz değişince ilerleme taşınmaz.
- **Doğrulama:** `tools/gen_segments.py` her parçayı, ilgili seviyenin hızı ve zıplama hakkıyla oyunun fiziğini simüle ederek doğrular; parçalar arası boşluk zıplama menzilinden büyüktür. Oyunun kurduğu seviyeler ayrıca bütün olarak doğrulanır (1-8 doğrulandı).

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
- Ücretsiz çekirdek (tüm seviyeler oynanabilir) + **ödüllü reklam** (isteğe bağlı: ölünce kaldığın yerden devam / ekstra kozmetik). Geçiş reklamı yalnızca seviye bitişinde ve en fazla 3-4 seviyede bir; oynanış sırasında asla.
- Reklam altyapısı: AdMob (Godot eklentisi), AB için onay (UMP/GDPR) ve reklam kimliği izin akışı; çocuklara yönelik kategoriye girilmemeli (yaş derecelendirmesi 12+/PEGI 7 civarı hedeflenir).
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
