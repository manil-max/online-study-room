# v57 Ürün Sahibi Geri Bildirim Raporu

> **Tarih:** 1 Ağustos 2026
> **Kaynak:** v57 stable yayınının ardından ürün sahibinin ilk cihaz izlenimleri
> **Amaç:** Gözlemi kaybetmeden, belirti ile teşhisi karıştırmadan kaydetmek
> **Durum:** **Bölüm 3 ham kayıttır** — kök neden veya çözüm iddiası içermez.
> Kök neden çalışması bu raporun 4. bölümünde, iş paketleri `progress.md`'dedir.

## 1. Kapsam

Bu rapor, `docs/V56-SAHIP-GERI-BILDIRIM-RAPORU.md` ile aynı sözleşmeyi izler:
önce sahibin söylediği aynen yazılır, sonra normalize edilmiş belirti kaydı
gelir. Sahibin cümlesi ile ajanın yorumu **hiçbir yerde birbirine karışmaz**.

Sahibin açık talebi (2026-08-01): *"ilk izlenimler bunlar; önce normal not al,
sonra sorunları detaylı bir şekilde bul, sonrasında bunları WP'ler hâlinde
detaylı progress.md'ye yaz."* Bu dosya birinci ve ikinci adımın çıktısıdır.

## 2. Kanıt sınıfları

| Sınıf | Anlamı |
|---|---|
| **Doğrudan gözlem** | Sahip cihazda açıkça gördü |
| **Şüpheli belirti** | Güçlü izlenim var; henüz kesin değil |
| **Ürün isteği** | Mevcut davranış hata olmasa bile istenen yeni davranış |
| **Ürün kararı** | Sahibin bağlayıcı kararı; tartışmaya açık değil |

---

## 3. Ham kayıt (sahibin kendi ifadesi)

> Aşağıdaki dokuz madde sahibin yazdığı metnin **anlamı korunarak** alınmış
> kaydıdır. Yorum, teşhis ve çözüm önerisi bu bölüme girmez.

### V57-N01 — Dürtme bekleme mesajı İngilizce'de de Türkçe

"Mesela aynı kişiyi 20 dk sonra dürtebilirsiniz mesajı, İngilizce'de bile
Türkçe yazılmış."

### V57-N02 — Ünvan seçimi kalıcı görünmüyor + seçici yerleşimi kötü

"Title seçtikten sonra grupta falan duruyor ama tekrar Başarımlar kısmına
girince 'no title selected' yazıyor. Bir de bazen uzun bir tane seçince altına
'choose title' butonu kayıyor, o da gereksiz yer kaplıyor. Bence üstüne basınca
seçenekler çıksa güzel olur. Basınca alttan açılan kartlar şeklinde yapma; ders
seçmedeki gibi seçenekler butonun orada çıksın."

### V57-N03 — Görev tekrar açıklaması eski metinde kalmış

"Task kısmında kaç günde yenilendiği seçiliyor ama 'refresh every day' yazıyor
hâlâ; açıklama eski."

### V57-N04 — Seri göstergesi her zaman görünmeli ve üç durumlu olmalı

"Ana ekrandaki sayaç widget'ında sol üstte seriyi belli eden kısım her zaman
olsun, daha hiç seri yokken bile. Ve aslında söylemiştim, 3 farklı durumda
olacak orası, chess.com'daki gibi:

1. **Durum:** Dün ve ondan önceki gün görev yapılmamış ve sıfırlanmış durumda:
   gri soluk alev işareti ve '0' yazacak.
2. **Durum:** Dün yapılmamış ama ondan önceki gün yapılmış, yani seri
   duraklatmaya girmiş; burada bir tane pause işareti olması lazım (chess.com'daki
   gibi). Eğer görev bugün de yapılmazsa seri 0'lanacak, eğer yapılırsa normal
   3. duruma geçilecek. **Koruma hakkı sınırsız** bu arada: mesela bir kişi 1 gün
   hedefe ulaşıp yarın yapmayarak, 100 gün boyunca 50 kere hedefe ulaşıp 100
   günün sonunda 50 seriye sahip olabilir.
3. **Durum:** O günün hedefine ulaşılmış; o an şu ankinin aynısı, renkli ateş
   vesaire olacak."

### V57-N05 — Aynı seri mantığı grup hedefinde de geçerli

"Kısaca direkt chess.com'daki mantığın aynısını istiyorum; aynısı grup hedefi
için de geçerli."

### V57-N06 — Global senkron widget'ta bozuldu

"Global senkron muhabbetinde artık bildirimde çift cihazda çalışıyor, ama
Android ana ekran widget'ında olmuyor; o senkronu bozdu, ona bakmak lazım."

### V57-N07 — Grupta sessize alma işareti bulunamıyor

"Muted kısmı var ayarlarda ama grupta mute işaretini bulamadım; eklememiş de
olabilirsin."

### V57-N08 — "Çalışan kişiyi dürtemezsin" uyarısı dilde ve tekrarda sorunlu

"'Çalışan kişiyi dürtemezsin' uyarısı da sanırım Türkçe idi, kontrol et. Bir de
bir kere çıktı, daha çıkmadı — her denediğinde tabii ki araya bir delay koyup
uyarıyı göstermek lazım."

### V57-N09 — Yönetici mesajlaşması: gönderen kendi mesajını görmüyor, push yok

"Admin kısmında mesajlaşma çalıştı ama admin olarak ben mesaj gönderdiğimde
kendi ekranımdan mesajımı göremedim; ama karşıya gitti. Karşı tarafa da bildirim
gitmedi. Bana da 'mesaj geldi' diye bildirim gelmedi bu arada. Admin tarafında
iyileştirmeler var ama hâlâ sorunlar var; arayüzden tut sisteme kadar bunlarda
daha iyi profesyonelleşmemiz lazım, detaylı titiz bir çalışma lazım."

---

## 4. Normalize edilmiş belirti kaydı

> Bu bölüm ham kaydı sınıflandırır ve kabul ölçütünü netleştirir. **Kök neden
> analizi bu raporun ekinde değil, `progress.md` WP kartlarındadır.**

| Kod | Belirti | Sınıf | Öncelik |
|---|---|---|---|
| V57-N01 | Dürtme bekleme uyarısı EN dilinde TR metin | Doğrudan gözlem | Yüksek (l10n kapısı) |
| V57-N02 | Ünvan seçimi yeniden girişte "seçili değil"; seçici yerleşimi | Doğrudan gözlem + ürün isteği | Yüksek |
| V57-N03 | Görev tekrar açıklaması aralığı yansıtmıyor | Doğrudan gözlem | Orta |
| V57-N04 | Seri rozeti koşullu gizleniyor; üç durum yok | Ürün kararı | Yüksek |
| V57-N05 | Aynı seri modeli grup hedefinde de | Ürün kararı | Yüksek |
| V57-N06 | Ana ekran widget'ı çoklu cihaz senkronunu almıyor | Doğrudan gözlem | Kritik |
| V57-N07 | Grup yüzeyinde sessize alma göstergesi/eylemi yok | Doğrudan gözlem | Orta |
| V57-N08 | Dürtme reddi uyarısı: dil + yalnız bir kez görünme | Doğrudan gözlem | Yüksek |
| V57-N09 | Yönetici konuşması: gönderenin kendi mesajı görünmüyor, iki yönde push yok | Doğrudan gözlem | Kritik |

### 4.1 Sahibin bağlayıcı kararları

1. **Seri modeli chess.com ile birebir aynı olacaktır.** Koruma (duraklatma)
   hakkı **sınırsızdır**; kullanıcı bir gün hedefi tuttursa, ertesi gün
   tutturmasa, seri sıfırlanmaz — duraklatılır. Ancak duraklatmayı izleyen gün
   de hedef tutturulmazsa seri **0** olur.
2. **Seri rozeti daima görünür.** Seri sıfırken bile gri soluk alev + `0`.
3. **Aynı model grup hedefi için de geçerlidir.**
4. **Ünvan seçici alttan açılan kart (bottom sheet) OLMAYACAK.** Ders seçimindeki
   gibi, butonun bulunduğu yerde açılan seçenek listesi olacak.
5. **Yönetici tarafı ayrı ve titiz bir çalışma gerektirir**; tek tek yama
   yerine arayüz ve sistem birlikte ele alınacaktır.

## 5. Bu rapor ne değildir

- Kök neden iddiası değildir (bölüm 3 için).
- Kapsam kararı değildir; WP kesimi `progress.md`'de yapılır.
- Cihaz kabulü değildir; her düzeltmenin kendi kabul kanıtı olur.
