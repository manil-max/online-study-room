# v64 — proje sahibi geri bildirimi (2026-08-10)

> Sahip cihazda `v64`'ü gezdi ve altı madde bıraktı. Bu dosya **karar kaydı
> değil, iş listesidir**; her madde ayrı bir WP olur.
>
> 🔴 Önce olumlu: sınav geri sayımı kartı **çalışıyor** — sahip "o kart güzel
> çalışıyor" dedi. Aşağıdaki 2. madde o kartın tek kusuru.

---

## 1. Geri sayım kartının adı fazla dar

**Sahip:** *"sınav countdown sayacının ismini 'geri sayım' ya da genel başka bir
isim koysak güzel olabilir."*

Kart bugün yalnız sınav diyor ama kullanıcı oraya her tarihi giriyor (tatil,
doğum günü, teslim tarihi). İsim özelliği daraltıyor.

**Etki:** `homeSinavGeriSayimi` ve çevresindeki metinler (TR + EN), varsayılan
ad `homeSinavVarsayilanAd`. Ürün kararı: yeni isim ne olacak?

---

## 2. 🔴 Kalem simgesi TIKLANMIYOR — hata bende

**Sahip:** *"kartın sağ üstünde kalem simgesi var, edit için koymuşsun sanırım
ama basınca bir şey olmuyor; editlemek için soldan listeye basmak gerekiyor.
bu saçma değil mi?"*

Haklı ve sebebi belli. `dday_card.dart`: kalem ikonu `CardScaffold`'un
**header**'ında; dokunma hedefi (`InkWell`, `Key('dday-card-open-editor')`) ise
**bodyBuilder** içinde. Header gövdenin dışında olduğu için simge tıklanabilir
değil — süs gibi duruyor ve kullanıcıyı yanıltıyor.

**Yapılacak:** ya kalem gerçek bir düğme olsun (aynı pencereyi açsın), ya da
başlık da dokunma hedefine girsin. Testi: kalemi bulup `tap` etmek pencereyi
AÇMALI. Şu an o test yok — kart testleri gövdeye dokunuyor, o yüzden kusuru
göremedi. (Bu, `docs/URUN-POLITIKALARI.md`'de yazılı "kullanıcının gördüğü
şeyi test et" dersinin bir örneği daha.)

---

## 3. 🔴 Kart içi kaydırma ana ekranı takıyor

**Sahip:** *"ana ekran kartlarında bazı kartlarda hâlâ gereksiz kart içinde
aşağı yukarı kaydırma var; onlar yüzünden ana ekran akıcı kaymıyor, parmağım
onların üstündeyse takılıyor. Weekly rhythm ve sayaç kartı mesela. Kartı ne
kadar büyütürsem büyüteyim gene var. başkaları da olabilir, her kartı kontrol
et."*

WP-508 bu sınıf için `cardScrollIfOverflows` + `CardOverflowScrollPhysics`
yazmıştı: içerik sığıyorsa jest dış sayfaya gitmeli. Demek ki bu iki kartta
içerik **gerçekten taşıyor** (o zaman düzen sıkıştırılmalı) ya da kaydırıcı
sığdığı hâlde jesti yutuyor.

**Yapılacak:** her pano kartı için, üç boyutta ve gerçekçi veriyle, kaydırma
payının **sıfır** olduğunu ölçen bir kapı. WP-632'de `dday_multi_exam` testinde
kullanılan `maxScrollExtent == 0` ölçüsü birebir uygulanabilir — orada gerçek
bir taşmayı yakalamıştı. Tek tek kart değil **envanter** taransın; sahip
"başkaları da olabilir" diyor ve haklı.

---

## 4. Gece teması çok erken devreye giriyor

**Sahip:** *"gece gündüzde erken gece oluyor, onu düzeltmek lazım. hafif hafif
kararsa falan ya da saatleri daha iyi ayarlasak — bunu konuşuruz."*

İki ayrı fikir var ve ikisi farklı iş:
- eşik saatlerini düzeltmek (küçük),
- kademeli geçiş / yumuşak kararma (daha büyük, animasyon ve tema katmanı).

**Ürün kararı gerekiyor:** hangi saatler? Kademeli mi, sert mi?

---

## 5. Saat dilimi — şimdilik dokunma, sonrası için planla

**Sahip:** *"global için saat sisteminde sorun varmış gibi bir his var. şu an
Play Store testindeyken İstanbul host kalsın, sorun yok; ama sonrası için not
edelim, planlayalım, sorun olmasın."*

Bu, `docs/URUN-POLITIKALARI.md` §5'te zaten yazılı olan kararla uyumlu:
ürünün tek takvim sınırı `Europe/Istanbul` ve **açılışta yalnız Türkiye**.
Sahip o kararı bozmuyor, yalnız uluslararası açılım için hazırlık istiyor.

**Yapılacak (yayın sonrası):** kullanıcı başına saat dilimi kararının maliyet
analizi. `day` sütunu materialize edilmiş durumda (`0073`), yani karar
migration + backfill + tüm istatistik zinciri demek. Analiz yazılsın, karar
sahibe sunulsun; kod yazılmasın.

---

## 6. Profil zenginleşsin (Clash Royale örneği)

**Sahip:** *"gruptakilerin profiline girince görevlerindeki ilerlemeleri
görelim (gizliler hariç). profilde günlük aktif, günlük serisi ve rekorları
falan olsa güzel olur. Clash Royale'de de mesela güzel bir profil sistemi
var."*

İki parça:
- **başkasının profilinde görev ilerlemesi** — gizli başarımlar HARİÇ (sahip
  bunu kendisi söyledi, gizlilik kuralı korunuyor),
- **kendi profilinde** günlük seri, aktif gün, rekorlar.

🔴 Dikkat: bu, başkasının verisini gösteren bir yüzey. RLS ve
`can_see_user_sessions` sözleşmesi zaten var (`0024`); yeni alanlar o kapıdan
geçmeli, etrafından değil. Ayrıca WP-637 ile "seri" ve "aktif gün" artık
**farklı** ölçüler — profilde ikisi de gösterilecekse tanımları ayrı yazılmalı,
yoksa sahibin bu gece yaşadığı karışıklık tekrarlar.

---

## Sıra önerisi (liderin görüşü, sahip değiştirebilir)

1. **Madde 2** — kalem düğmesi. Küçük, kusur bende, kullanıcıyı yanıltıyor.
2. **Madde 3** — kart içi kaydırma. Her ekranda hissediliyor, envanter taraması
   gerektiriyor ama ölçüsü hazır.
3. **Madde 1** — isim. Ucuz, ürün kararı bekliyor.
4. **Madde 4** — gece teması. Ürün kararı bekliyor.
5. **Madde 6** — profil. En büyüğü, yayın sonrası.
6. **Madde 5** — saat dilimi. Yalnız analiz, kod yok.
