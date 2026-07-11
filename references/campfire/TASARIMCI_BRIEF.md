# Kamp Ateşi Sahnesi — Tasarımcı Asset Brief'i

Bu belge, "Odak Kampı" uygulamasındaki **kamp ateşi sahnesi** için gereken
karakter (hayvan) görsellerinin/animasyonlarının nasıl teslim edilmesi
gerektiğini eksiksiz tanımlar. Amaç: teslim edilen dosyaları geliştirici
(uygulama tarafı) hazır sahneye **doğrudan** yerleştirebilsin.

> **Hedef stil:** Bu klasördeki (`references/campfire/`) referans görseller —
> "Party Animals" tarzı, yumuşak, tombul, gölgeli/hacimli chibi hayvanlar, gece
> ormanı kamp ateşi. Aynı çizim dili ve poz seti hedefleniyor.

---

## 0) Geliştirici NEYİ çiziyor, tasarımcı NEYİ veriyor?

**Geliştirici (uygulama) çiziyor — bunları asset'e KOYMAYIN:**
- Gece orman arka planı (ay, yıldızlar, çam ağaçları)
- Kamp ateşi (alev, kor, kıvılcım, sıcak ışık)
- Zemin/açıklık ve genel ışık atmosferi
- Üye **adı** ve **canlı süre** etiketleri (yazılar)

**Tasarımcı veriyor:**
- Her hayvanın **pozları** (aşağıdaki matris) — tek tek, **şeffaf arka planlı**
- (Tercihen) her hayvanın oturduğu **kısa kütük** poz görseline gömülü olabilir
  (bkz. §4 — Kütük kararı)

---

## 1) Hangi hayvanlar? (Karakter listesi)

Her karakterin bir **kimliği (id)** var — dosya adlarında bu id kullanılacak.

### Zorunlu (MVP) — 12 karakter
| id | Ad |
|----|-----|
| `bear` | Ayı |
| `fox` | Tilki |
| `rabbit` | Tavşan |
| `cat` | Kedi |
| `dog` | Köpek |
| `panda` | Panda |
| `owl` | Baykuş |
| `frog` | Kurbağa |
| `penguin` | Penguen |
| `koala` | Koala |
| `tiger` | Kaplan |
| `hedgehog` | Kirpi |

### Opsiyonel — sonradan eklenebilecek genişletme seti
`lion` (Aslan), `monkey` (Maymun), `giraffe` (Zürafa), `sheep` (Koyun),
`deer` (Geyik), `zebra` (Zebra), `squirrel` (Sincap), `raccoon` (Rakun),
`crocodile` (Timsah), `dino` (Dino), `manatee` (Denizayısı), `pug` (Mops),
`shark` (Köpekbalığı)

> Bütçeye göre önce 12 zorunlu karakteri yapmak yeterli; kod, olmayan hayvan için
> otomatik olarak mevcut çizime düşer.

---

## 2) Hangi pozlar? (Poz matrisi)

Her karakter için **4 poz** (referans katalogdaki pozların birebir karşılığı):

| Poz (dosya adı) | Ne yapıyor | Referans karşılığı |
|---|---|---|
| `working` | Kütüğünde oturur, **kucağında açık laptop**, iki patisi klavyede, ekrana bakar, **uyanık** | Kataloğdaki "Aktif" (laptoplu) |
| `roasting` | Oturur, bir kolu öne uzanır, elinde **dala geçmiş marşmelov** ateşe doğru | Kataloğdaki "Roasting" |
| `idle` | Uyanık ama boşta oturur, eller kucakta/rahat, laptop yok | Nötr oturuş |
| `sleepy` | **Uyur** — gözler kapalı, baş hafif yana eğik, kıvrılmış/rahat | Kataloğdaki "Sleepy" |

**Opsiyonel 5. poz:** `snacking` — türüne özel yiyecek yer
(ör. ayı→bal, panda→bambu, penguen→balık, koala→okaliptus, maymun→muz,
tavşan→havuç, kirpi→mantar, kurbağa→sinek). İstenirse eklenir.

> **Laptop ve marşmelov poza gömülü olsun** (ayrı katman gerekmez). "working"
> görselinde laptop çizili, "roasting" görselinde marşmelovlu çubuk çizili gelsin.

---

## 3) Teknik spesifikasyon (EN ÖNEMLİ KISIM)

Tüm pozların sahnede düzgün oturması için **hepsi aynı kurallarla** üretilmeli.

### Tuval / boyut / hizalama
- **Tuval boyutu:** her dosya **1024 × 1024 px, kare** (kaynak). (Uygulamaya
  geliştirici ~512px'e optimize edecek — sen 1024 ver.)
- **Şeffaf arka plan** (PNG alpha / 32-bit). Beyaz-renkli zemin YOK.
- **Yatayda ortalı:** hayvan tuvalin yatay merkezinde.
- **Sabit "oturma çizgisi":** hayvanın **popo/kütüğe değdiği alt nokta HER
  POZDA aynı Y'de** olmalı — öneri: tuvalin üstünden **%78** (1024'te y≈800).
  Böylece poz değişince hayvan yerinde durur, zıplamaz.
- **Sabit ölçek:** tüm karakterler **görünüş olarak benzer boyutta** dursun
  (ayı ile tavşan aşırı farklı büyüklükte olmasın). Hayvan gövdesi kabaca tuvalin
  **%55–65 yüksekliğini** kaplasın, yatayda **~%70 genişliği** aşmasın.
- **Tüm pozlar hizalı:** working/roasting/idle/sleepy üst üste konduğunda kafa ve
  oturma noktası aynı yerde olmalı.

### Bakış yönü / perspektif
- Tüm hayvanlar **öne (izleyiciye) ve hafif aşağı** baksın (¾ önden görünüm).
  Ateş, hayvanın **önünde-altında** kabul edilir.
- **`roasting`** pozunda marşmelovlu çubuk **öne-aşağı, kadrajın alt-orta**
  bölgesine (ateşe) doğru uzansın.
  *(Not: geliştirici görseli gerektiğinde yatay AYNALAYABİLİR; yani kolu bir yöne
  uzanan tek bir roasting yeterli, halka üzerinde diğer tarafa yansıtılır.)*

### Işık / renk (sahneye otursun diye)
- **Sıcak anahtar ışık alttan-önden** (kamp ateşi): hayvanın alt-ön yüzeyleri
  sıcak turuncu vursun.
- **Soğuk/loş dolgu üstten** (ay ışığı): üst-arka biraz koyu.
- Gövdede yumuşak **iç gölge / AO** olsun (hacim için). **Yere düşen gölge
  KOYMAYIN** — onu geliştirici çiziyor. (Gövde altındaki hafif temas gölgesi
  şeffaf bırakılmalı ya da çok yumuşak/merkezî olmalı.)
- Palet gece ormanına uygun; referans görsellerdeki doygunluk hedef.

---

## 4) Kütük kararı (iki seçenek — birini seç)

- **Seçenek A (önerilen — referansa en yakın):** hayvan **kendi kısa kütüğünde
  oturur şekilde** çizilsin, kütük görsele **gömülü** gelsin (şeffaf zemin).
  Kütük yatay, kısa, hayvanın altında. Tüm hayvanlarda **aynı kütük stili/boyu**.
- **Seçenek B:** sadece hayvan (kütüksüz); geliştirici kütüğü ayrı çizer. Bu
  durumda hayvan, görünmez bir kütükte oturuyormuş gibi çizilmeli (bacak/duruş
  ona göre).

> Hangisini seçersen söyle; kod ona göre kurulur. Seçenek A daha az uyum sorunu
> çıkarır.

---

## 5) Animasyon (istersen — 3 yol)

Statik de olur (geliştirici koddan nefes/salınım katar), ama animasyon istiyorsan:

### Yol 1 — Rive (`.riv`)  ⭐ ÖNERİLEN
- **Her hayvan için bir `.riv`** (ya da tüm hayvanlar tek dosyada + "species"
  girişi). İçinde **tek State Machine**.
- **State Machine adı:** `Camp`
- **Giriş (input):** bir **Number input** adı **`pose`**, değerler:
  `0 = idle`, `1 = working`, `2 = roasting`, `3 = sleepy` (varsa `4 = snacking`).
  *(Alternatif: `isWorking`, `isRoasting`, `isSleepy` adlı Boolean input'lar;
  hiçbiri true değilse idle.)*
- Her state **kendi içinde döngülü** olsun (nefes alma, hafif salınım). Öneri
  döngü süresi **2.5–4 sn**, kusursuz loop.
  - `working`: patiler klavyede hafif tıklar, ekran hafif titrer/parlar
  - `roasting`: marşmelov ateşin üstünde hafif sallanır, ara sıra çubuk döner
  - `sleepy`: yavaş nefes, ufak "zzz"
  - `idle`: sakin nefes
- State'ler arası geçiş `pose` değişince otomatik.
- **Teslim:** çalıştırılabilir `.riv` + düzenlenebilir **kaynak (.rev)** dosyası.

### Yol 2 — Lottie (`.json`)
- **Poz başına bir döngülü json** (`bear_working.json` …). 30 fps, 2.5–4 sn,
  kusursuz loop, şeffaf zemin. After Effects + Bodymovin export.

### Yol 3 — Kare-kare (sprite sheet / PNG dizisi / APNG)
- Poz başına **N kare** (öneri 24–48 kare, 24–30 fps), tek bir yatay/ızgara
  **sprite sheet** ya da numaralı PNG dizisi (`bear_working_00.png` …).
  Kare boyutu ve fps'i belirt.

> **En pratiği:** Rive. Zorsa statik PNG ver, hareketi koddan katarız; sonra
> Rive'a yükseltiriz.

---

## 6) Dosya isimlendirme ve teslim

### İsimlendirme (kesin kural)
```
<id>_<poz>.<uzantı>
```
Örnekler:
```
bear_working.png     bear_roasting.png     bear_idle.png     bear_sleepy.png
fox_working.png      fox_roasting.png      fox_idle.png      fox_sleepy.png
panda_working.png    ...
```
Rive için: `bear.riv`, `fox.riv`, … (tek dosyada tüm pozlar + `pose` girişi).

- Küçük harf, İngilizce id'ler (yukarıdaki tablo).
- Poz adları: `working`, `roasting`, `idle`, `sleepy` (varsa `snacking`).

### Teslim paketi
- **Uygulama asset'leri:** yukarıdaki adlandırmayla, klasör: `assets/critters/`
  (ya da bana zip/klasör olarak ver, ben yerleştiririm).
- **Kaynak dosyalar** (düzenleme için): AI/PSD/SVG veya Rive `.rev` — ayrı klasör.
- Format: **PNG-32 (şeffaf)** veya Rive `.riv` / Lottie `.json`.
- Renk profili: sRGB.

---

## 7) Teslimat özeti (checklist)

**Statik PNG seçilirse (MVP):**
- [ ] 12 hayvan × 4 poz = **48 adet** 1024×1024 şeffaf PNG
- [ ] Hepsi aynı oturma çizgisi + aynı ölçek + aynı bakış yönü
- [ ] `working`'de laptop, `roasting`'de marşmelovlu çubuk gömülü
- [ ] (Opsiyonel) `snacking` pozu = +12 PNG
- [ ] Kaynak dosyalar

**Rive seçilirse (animasyonlu):**
- [ ] 12 hayvan × `.riv` (State Machine `Camp`, `pose` input: 0–3)
- [ ] Her state döngülü (breathing) + kusursuz loop
- [ ] `.riv` + `.rev` kaynak

---

## 8) Önce küçük bir test partisi (önemli)

Tüm seti üretmeden önce **1 hayvanın 4 pozunu** (ör. `bear_working / bear_roasting
/ bear_idle / bear_sleepy`) teslim et. Geliştirici sahneye oturtup ekran görüntüsü
paylaşacak; hizalama/boyut/ışık doğrulanınca formatı sabitleyip gerisi üretilir.
Böylece 48 dosyayı yanlış spec'le üretme riski olmaz.

---

### Sorular / netleştirme
- Kütük: Seçenek A mı B mi?
- Animasyon: Rive mi, Lottie mi, statik mi?
- `snacking` pozu ve genişletme hayvanları isteniyor mu?
