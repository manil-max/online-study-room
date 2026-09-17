# V86 planı — sahip geri bildirimi (2026-09-17)

Kaynak: sahip mesajı, v85 yayınlandıktan sonra. Altı başlık yedi iş paketine ayrıldı.
Sıra **etkiye** göre: önce çalışmayan iki şey, sonra ilk kullanım hissi, sonra senkron ve mağaza.

Kanıt etiketleri `.agents/AGENTS.md §0`: `Kodda doğrulandı` · `Cihazda doğrulanmalı` · `Ürün kararı gerekiyor`.

---

## WP-833 — "Google ile devam et" düğmesi cihazda görünmedi 🔴

**Sahip gözlemi:** buton yok.

**Kodda doğrulandı (buton yoksa sebebi bunlar değil):**
- `release.yml` env üretimi `GOOGLE_WEB_CLIENT_ID`'yi yazdı; v85 koşumunun (`35098855508`)
  logunda değer dolu (`1094303444274-0ge35…`). `env.play.json` aynı anahtarları taşır
  (workflow bunu derleme anında iddia ediyor).
- `googleSignInEnabledProvider` (`app/lib/features/auth/google_sign_in_availability.dart`):
  Android + kimlik dolu + `SupabaseConfig.isConfigured`. Üçü de v85 Play derlemesinde doğru.
- `auth_screen.dart:426` bloğu iki modda da çiziliyor; widget testleri düğmeyi görüyor.

**Açık olasılıklar (ölçülmedi):**
1. Cihazdaki sürüm v85 **değil**: kademeli yayın %20 iken Play güncellemeyi vermemiş olabilir;
   ya da telefonda GitHub kanalından kurulmuş APK duruyor olabilir (aynı `applicationId`).
2. Kullanıcı düğmeyi oturum **açıkken** aradı (giriş ekranı çizilmiyor).

**Yapılacak:**
- Ayarlar → Hakkında ekranına **tek satır teşhis**: sürüm + kanal + "Google girişi: açık/kapalı".
  Böylece "buton yok" bir daha tahmin olmaz, ekran görüntüsü cevabı verir.
- Yayın kapısı: stable kanalda `GOOGLE_WEB_CLIENT_ID` boşsa **derleme dursun** (şu an sessizce
  butonsuz APK üretiliyor; fail-closed davranış doğru ama yayın için sessiz).
- Sahipten tek bilgi: Play'den inen v85'te mi bakıldı, telefondaki sürüm kaç?

---

## WP-834 — Şifre belirleme ekranı "Beklenmeyen bir hata" dedi 🔴

**Sahip gözlemi:** sıfırlama bağlantısından gelen ekranda şifre yazdı, hata aldı; bir harf
değiştirince kabul edildi.

**Kodda doğrulandı:** `recovery_screen.dart:68` yalnız dört kodu çeviriyor
(`weakPassword`, `noSession`, `rateLimited`, `network`); geri kalan her şey
"Beklenmeyen bir hata oluştu."ya düşüyor. Supabase'in şifre reddi tek sebep değil:
`same_password` (eski şifreyle aynı), Supabase'in sızmış şifre listesi kontrolü ve
minimum karakter kuralı ayrı kodlarla geliyor. Bir harf değişince geçmesi
"aynı şifre" ya da "sızmış şifre" ihtimalini güçlendiriyor.

**Yapılacak:**
- Supabase'in döndürdüğü kodları tek tek eşle (`same_password`, zayıf şifre alt sebepleri),
  her biri için kendi Türkçe/İngilizce cümlesi olsun.
- Ekranda **kural metni** kalıcı dursun: en az 6 karakter, eski şifreyle aynı olamaz.
- Panelde şifre kuralının gerçekte ne olduğu okunacak (minimum uzunluk, sızmış şifre kontrolü)
  ve ekrandaki metin ona göre yazılacak — tahminle yazılmayacak.

---

## WP-835 — Varsayılan tema ve ilk kullanım hissi

**Sahip isteği:** varsayılan tema kötü; uygulamanın kapak/ikon renklerine yakın, sıcak, canlı,
tatlı bir ilk kullanım.

**Kodda doğrulandı:** 15 hazır tema var (`theme_presets.dart`), aralarında `campfire_night`
(kamp ateşi) da var; sorun temaların yokluğu değil, **varsayılanın seçimi**.

**Yapılacak:**
- Varsayılan preset kamp ateşi ailesine çekilecek; ilk açılışta bu tema gelecek.
- Mevcut kullanıcıların seçtiği tema **değişmeyecek** (yalnız hiç seçim yapmamışlar etkilenir).
- Karşılaştırma ekran görüntüleriyle sahip onayına sunulacak (`Ürün kararı gerekiyor`).

---

## WP-836 — Ana ekran varsayılan düzeni ve kart ekleme

**Sahip isteği:** sayaç kartı daha uzun gelsin; eklenen kartlar elle boyutlandırmaya gerek
kalmadan düzgün gelsin; kart eklerken önizleme olsun.

**Kodda doğrulandı:** boyutlar `dashboard_card.dart`'ta üç kademe (`small/medium/large`) ve
`defaultCardHeight` satır yüksekliğinden türüyor. Yeni kartın hangi kademeyle eklendiği
kart türünden bağımsız — şikâyetin kaynağı bu.

**Yapılacak:**
- Her kart türü için **doğru varsayılan kademe** tanımlanacak (sayaç dâhil), eklenince o
  boyutla gelecek.
- Kart ekleme ekranında her kart için küçük önizleme.

---

## WP-837 — Tanıtım kartları sadeleşsin

**Sahip isteği:** "2 adımın 2. adımı" gibi metinler gereksiz; ana ekranda tek kart, düzenleme
modunda (basılı tutunca açılan yer) tek kart, istatistiklerde tek kart — kısa, sade, net.

**Kodda doğrulandı:** metin `app_tr.arb:1779` `tourAdim` — `"{total} adımın {current}. adımı"`.

**Yapılacak:** sayaç metni kaldırılacak; üç yüzeyde birer kart kalacak, metinleri yeniden yazılacak.

---

## WP-838 — Tema tercihi hesapta saklansın

**Sahip gözlemi:** yeni cihazda tema ayarı gitmiş.

**Kodda doğrulandı:** `theme_settings.dart` yalnız `SharedPreferences` kullanıyor; sunucuya
hiçbir şey yazılmıyor, yani cihaz değişince tercih gider. Özel temalar da aynı yerde.

**Yapılacak:** profil tarafında tercih sütunu (migration `0143`), giriş sonrası senkron,
çakışmada "en son yazan kazanır". Çevrimdışıyken yerel tercih çalışmaya devam eder.

---

## WP-839 — Play mağaza sayfasının Türkçesi

**Sahip isteği:** TR kullanıcılar için Türkçe mağaza sayfası.

**Yapılacak:** başlık, kısa açıklama (80), tam açıklama (4000) ve görsel metinleri Türkçe
hazırlanacak; sahip Play Console → Mağaza girişleri → Türkçe ekleyip yapıştıracak.
Ekran görüntülerinin üstündeki yazılar da Türkçe üretilecek.

---

## Sıra

1. WP-833, WP-834 — çalışmayan iki şey.
2. WP-837, WP-836 — ilk kullanımın anlaşılırlığı.
3. WP-835 — tema kararı (sahip onayı gerekir).
4. WP-838 — senkron (migration).
5. WP-839 — mağaza metinleri (sahip yapıştırır, kod gerekmez).
