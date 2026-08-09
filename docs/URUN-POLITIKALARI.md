# Ürün Politikaları — bağlayıcı kararlar

> Bunlar öneri değil **karar**. Kaynağı `docs/RAKIPANALIZI.md` (439 gerçek rakip
> yorumunun tema sayımı) ve `docs/RAKIPANALIZI-DEGERLENDIRME.md` (her iddiası koda
> bakılarak doğrulanmış ikinci okuma, 2026-07-28).
>
> Değerlendirme dosyası §5'te yayın kapısına eklenmesi gereken **iki** madde
> saymıştı: bu metin ve Play ülke listesi. Bu dosya birincisidir.
>
> 🔴 Bu politikalar yazılı olmasaydı altı ay sonra sessizce ihlal edilirdi — rakip
> tam olarak böyle kaybetti. Bir maddeyi değiştirmek proje sahibinin açık kararını
> gerektirir; ajanlar kendi başına gevşetemez.

---

## 1. Regresyon politikası — en kanıtlı ders

**Kural:** Kullanıcıya görünen bir düzen değişirse **eski düzen seçenek olarak
kalır**. Bir özellik kaldırılacaksa önce sürüm notunda duyurulur ve **bir sürüm
boyunca** geri alınabilir olur.

**Kanıt:** Rakibin Ağustos 2025 ana ekran değişikliği tek başına 41 yorumun 32'sini
üretti. My Study Life ve Forest'ta aynı desen. Rakip geri adım atıp *"Klasik / Yeni
ana ekran"* seçeneğini koyunca öfke söndü — yani çözüm özelliği geri almak değil,
**seçenek bırakmaktı**.

**Nasıl uygulanır:** Ana ekran, sayaç ekranı, istatistik düzeni ya da grup akışında
görünür bir yeniden düzenleme yapan her WP, geri dönüş seçeneğini aynı WP içinde
getirir. Getirmiyorsa WP eksiktir.

---

## 2. Ücret politikası — kalıcı ve bağlayıcı

> **Sayaç, gruplar, istatistikler ve bildirimler kalıcı olarak ücretsiz ve
> reklamsızdır. İleride ücretli bir şey gelirse yalnız kozmetik olur ve çalışarak
> da kazanılabilir.**

**Kanıt:** Rakibin **en taze** öfke kaynağı 2026'da eklenen açılış reklamları ve
satın alınabilen "flame"ler. Yani ödemeyle atlanabilen ilerleme, ürünün kendi
sözünü bozuyor.

**Nasıl uygulanır:** Bu cümle mağaza açıklamasına ve SSS'e girer. Yazıldığı andan
itibaren **bağlayıcıdır** — sıfır maliyetli en güçlü farklılaştırıcı, ama ancak
tutulursa. Reklam SDK'sı, ödeme duvarı arkasında sayaç/grup/istatistik özelliği ve
"XP satın al" mekaniği **yasaktır**.

---

## 3. Zorlama yok politikası

**Yasak olanlar:**

- **Uygulama engelleme / telefon kilitleme.** Rakipte 40 yorumun 33'ü bu yüzden.
  Doğru sonuç "isteğe bağlı yap" değil, **hiç yapma**.
- **Mola cezası** (Study Bunny deseni: mola verince ilerleme silinir).
- **Kolektif ceza.** Flora'da oturum sahibi çıkınca herkesin ağacı ölüyor.
  Kamp ateşi, grup hedefi ve seri mekanikleri tasarlanırken *"birinin hatası
  herkesi cezalandırır"* kalıbı **yasaktır**.
- **Boşta kalma (idle) tespiti.** İnvazif, pil yakar ve yanlış pozitifte
  kullanıcının **gerçek çalışma saatini siler** — yani rakibin en sert şikâyetini
  (süre kaybı) biz üretmiş oluruz. Kazanım zaten sunucu-yetkili ve lease
  sweeper'lı (`0089`); koruma oradan geliyor, kullanıcıyı gözetlemekten değil.

**Nedeni tek cümlede:** Bu ürün kullanıcıyı çalışmaya **zorlamıyor**, çalışırken
**yanında duruyor**.

---

## 4. Yıkıcı eylem politikası — "durdur ≠ sil"

**Kural:** Sayacı durdurmak ile oturumu silmek görsel ve metinsel olarak **ayrık**
olmalı; silme onay ister ve geri alınabilir olmalı.

**Kanıt:** Rakipte kullanıcılar yanlış butona basıp saatlerini sildi
(`RAKIPANALIZI` §2.1.2/2).

🔴 **Bu politikanın bizdeki karşılığı 2026-08-09'da somutlaştı.** Proje sahibinin
kardeşi gece sayacı durdurduğunu sanmış, sabah 11 saatlik oturumla uyanmıştı.
Teşhis (`docs/analiz/WP-595-sayac-xp-teshis.md`): son eylem **durdurma değil
başlatmaydı** — ikisi aynı yerdeki aynı buton. Yani bu madde teorik bir ders değil,
üründe **yaşanmış** bir olay. Aynı sınıfın diğer yüzü: geri alınamayan kazanım
(XP defteri ekle-yalnız çalışır, oturum silinse de bakiye dönmez).

**Yayın öncesi kontrol maddesi:** cihazda tek tur — durdur/başlat ayrımı ve silme
onayı gözle doğrulanır.

---

## 5. Dağıtım politikası — açılışta yalnız Türkiye

**Kural:** Mağaza ülke listesi açılışta **Türkiye**. Uluslararası açılım, kullanıcı
başına saat dilimi kararı verildikten **sonra**.

**Nedeni:** Ürünün tek takvim sınırı `Europe/Istanbul`
(`app/lib/core/stats/istanbul_calendar.dart`, `0073_session_day_stamp.sql`) ve bu
**bilinçli** bir karar. Play/Store varsayılanı ise tüm dünyadır: Berlin'de 23:30'da
çalışan biri süresini ertesi güne yazılmış görür — rakibin 24 yorumluk gün-sınırı
şikâyetinin aynadaki hâli.

Bu bir konsol ayarıdır, kod değil.

---

## 6. Kapsam politikası — araç yığınına girmiyoruz

**Kural:** Sözlük, hesap makinesi, flashcard, beyaz gürültü, not defteri, takvim —
**hiçbiri eklenmiyor**.

**Nedeni:** Rakibin en çok övülen yanı "tek uygulamada her şey". Bu yarışa girmek
bizi bitirir; onlar beş yıldır oradalar. Bizim kazandığımız yer sayacın hiç
kaybetmemesi ve grubun canlı olması.

**Tek istisna önerisi (henüz yapılmadı, yayın sonrası):** sınav geri sayımı
(*"YKS'ye 214 gün"*). Neredeyse bedava, tek satır, TR öğrenci bağlamının tam
merkezinde.

---

## 7. Kapsam dışı bırakılanlar (gerekçeleriyle)

| Talep | Karar | Gerekçe |
|---|---|---|
| Gün başlangıç saatini kullanıcı seçsin | **Hayır** | Rakibin şikâyeti 05:00 dayatması; istenen 00:00 ve **bizde zaten 00:00**. Ayarlanabilir yapmak `day` sütunu materialize olduğu için migration + backfill + tüm istatistik zinciri demek. Bedeli faydasından büyük. |
| Sesli / görüntülü ortak seans | **Hayır** | Hem maliyet hem taciz cephesi; kalıcı ücretsizlik hedefiyle uyumsuz (§2). |
| Boşta kalma tespiti | **Hayır** | §3. |
| Uygulama engelleme | **Hayır** | §3. |

---

## 8. Yayın sonrasına kabul edilenler

Sırayla — hiçbiri yayın kapısı değil:

1. Manuel oturuma **"elle eklendi" etiketi** (ceza değil şeffaflık; kazanım eşit
   kalır). Ayrıntı: `RAKIPANALIZI-DEGERLENDIRME` §3.
2. Sıralamayı gizleme / kişisel hedef modu
3. Sohbette görsel + alıntı
4. Ders klasörü
5. Çalışma dışı kategori
6. Sınav geri sayımı (§6)

**Zaten yapılmış olanlar:** AMOLED tema (`deep_amoled` paleti), hesap e-postası
değiştirme (`account_settings_screen.dart`).
