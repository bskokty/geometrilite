# Neon Pulse — Google Play'e yayın rehberi (reklamlı sürüm)

Bu rehber sırayla izlenecek adımları anlatır. **A–C senin yapacakların**, D'den sonrası otomatik derleme ve Play Console formlarıdır.

> Paket adı `com.bskokty.neonpulse`. İlk yüklemeden sonra **değiştirilemez**. Farklı bir ad istiyorsan `ci/android_preset.cfg` içindeki `package/unique_name` değerini ilk yüklemeden önce değiştir.

## A. AdMob hesabı ve reklam birimleri

1. https://admob.google.com adresine Google hesabınla gir ve hesabı oluştur (ülke, saat dilimi, para birimi). Ödeme için **Ödemeler** bölümünde kimlik/adres ve vergi bilgilerini tamamla (adres doğrulama PIN'i posta ile gelebilir, bu birkaç hafta sürebilir).
2. **Uygulamalar → Uygulama ekle**: platform **Android**. Uygulama Play'de henüz yayında olmadığı için "Hayır" seç, adı `Neon Pulse` yaz.
3. Oluşan **Uygulama Kimliği**'ni not et. Biçimi: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` (içinde `~` var).
4. Bu uygulamada iki **reklam birimi** oluştur:
   - **Ödüllendirilmiş**: ad `devam-et`. Ödül: miktar 1, tür `continue`.
   - **Geçiş reklamı (Interstitial)**: ad `seviye-sonu`.
5. İki **Reklam Birimi Kimliği**'ni not et. Biçimi: `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ` (içinde `/` var).
6. **Gizlilik ve mesajlaşma → GDPR**: "Avrupa düzenlemeleri" mesajı oluştur ve uygulamana ata (AB/İngiltere kullanıcıları için onay penceresi). Oyundaki onay kodu bu mesajı gösterir. Mesajı yayınlamazsan AB'de reklam gelmez.

## B. GitHub'a kimlikleri gir (bir kez)

Depoda **Settings → Secrets and variables → Actions**:

**Variables** sekmesi (gizli değil, "New repository variable"):

| Ad | Değer |
|---|---|
| `ADMOB_APP_ID` | A3'teki uygulama kimliği (`~` li) |
| `ADMOB_REWARDED_UNIT_ID` | ödüllendirilmiş birim kimliği (`/` li) |
| `ADMOB_INTERSTITIAL_UNIT_ID` | geçiş reklamı birim kimliği (`/` li) |

Bunlar tanımlı değilken yapılan derlemeler **Google'ın test reklamlarıyla** çıkar. İmzalı (Play'e yüklenecek) derleme bu üçü olmadan bilerek başarısız olur; böylece yanlışlıkla test reklamlarıyla yayın yapılamaz.

## C. Yükleme anahtarını (upload key) oluştur

Bilgisayarında (Java kurulu olmalı) bir kez:

```bash
keytool -genkeypair -v -keystore neonpulse-upload.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Sorulan parolayı güvenli bir yere yaz. Dosyayı ve parolayı **yedekle ve kimseyle paylaşma**, depoya koyma. (Play Uygulama İmzalama sayesinde kaybolursa Play Console'dan yükleme anahtarı sıfırlanabilir, ama zaman kaybettirir.)

Dosyayı tek satıra çevir:

```bash
base64 -w0 neonpulse-upload.jks        # Linux
base64 -i neonpulse-upload.jks | tr -d '\n'   # macOS
```

**Secrets** sekmesine ("New repository secret") şunları ekle:

| Ad | Değer |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | yukarıdaki çıktı |
| `ANDROID_KEYSTORE_ALIAS` | `upload` |
| `ANDROID_KEYSTORE_PASSWORD` | anahtar deposu parolası (anahtar parolası da aynı olmalı) |

## D. Gizlilik politikası

Politika Vercel sitende yayında: **https://geometrilite.vercel.app/privacy** (kaynak: `public/privacy/index.html`). Play Console'daki "Gizlilik politikası" alanına bu adresi yaz. İletişim olarak deponun Issues sayfası yazılı. İstersen `public/privacy/index.html` ve `docs/privacy-policy.md` içinde kendi e-posta adresinle değiştir.

## E. AAB'yi derle

1. Depoda **Actions → Android AAB → Run workflow** (branch `main`).
2. Bitince (yaklaşık 10–15 dk) çalışmanın sayfasında **Artifacts** altından `neon-pulse-aab-release` dosyasını indir. İçinden `neon-pulse.aab` çıkar.
3. Derleme günlüğünde **"AAB içeriğini doğrula"** adımında ikonların ve hedef SDK 36'nın göründüğünü kontrol et.

Yeni sürüm yüklerken `ci/android_preset.cfg` içinde `version/code` değerini **bir artır** (Play aynı kodu iki kez kabul etmez), `version/name` değerini istediğin gibi güncelle.

## F. Play Console

1. **Uygulama oluştur**: ad `Neon Pulse`, dil, **Oyun**, **Ücretsiz**. Beyanları onayla.
2. **Ana mağaza girişi**: `store/listing.md` içindeki metinleri (EN, TR) kopyala. Görselleri `store/neon-pulse-store-assets.zip` içinden yükle: 512 ikon, 1024×500 öne çıkan grafik, ekran görüntüleri.
3. **Uygulama içeriği** bölümü (`store/listing.md` sonundaki tablolara göre):
   - Gizlilik politikası URL'si (D2'deki adres)
   - **Reklamlar: Evet**
   - Hedef kitle: **13 yaş ve üzeri**
   - İçerik derecelendirme anketi (IARC)
   - **Veri güvenliği formu** (tabloda hazır, Google Mobile Ads SDK'ya göre)
4. **Test ve yayın → Kapalı test**: yeni bir sürüm oluştur, **Play Uygulama İmzalama**'yı kabul et ve E2'deki `neon-pulse.aab` dosyasını yükle. Sürüm notunu `store/listing.md`'den al.
5. **Kişisel hesap kuralı:** hesabın Kasım 2023'ten sonra açıldıysa üretime geçmeden önce **en az 12 test kullanıcısı 14 gün kesintisiz** kapalı testte olmalı. Test kullanıcılarını e-posta listesiyle ekle ve test bağlantısını gönder. 14 gün dolunca Play Console'dan "Üretime erişim için başvur" de.
6. Üretim sürümü: aynı AAB'yi üretim kanalına yükle ve incelemeye gönder.

## G. Yayından sonra

- AdMob'da uygulamayı Play mağaza girişine **bağla** (Uygulamalar → uygulamanı seç → Mağazaya ekle). Yeni uygulamalarda ilk günlerde reklam doluluğu düşük olabilir; bu normaldir.
- Gelir bu aşamada yalnızca reklamdır. "Reklamları kaldır" satın alması ileride eklenebilir.
- Test sırasında **kendi reklamlarına tıklama**. AdMob bunu geçersiz trafik sayar ve hesabı kapatabilir. Geliştirme için test reklam kimlikleri (depodaki varsayılanlar) kullanılır.

## Sorun giderme

| Belirti | Çözüm |
|---|---|
| Derleme "AdMob değişkenleri tanımlı olmalı" diyor | B adımındaki üç değişkeni ekle |
| Play "paket adı kullanılıyor" diyor | `package/unique_name` değerini değiştirip yeniden derle |
| Play "sürüm kodu zaten kullanıldı" diyor | `version/code` değerini artır |
| Play "hedef API düzeyi yetersiz" diyor | Derleme günlüğündeki `targetSdk` satırına bak; 36 olmalı |
| Reklam gelmiyor | Önce test kimlikleriyle dene; AB'de GDPR mesajını yayınladığından emin ol; yeni AdMob uygulamalarında gecikme olabilir |
