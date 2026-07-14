# İstatistik Görselleştirme R2 — Grafik Kataloğu ve Ürün Briefi (WP-67)

> **Durum:** Brief taslağı + önerilen ilk dilim · **implementasyon yok**  
> **Kanıt:** Mevcut metrik/grafik envanteri `Kodda doğrulandı`  
> **Kabul:** Ürün sahibi 3 soru + ilk grafik/tablo fallback’i onaylar · `Ürün kararı gerekiyor`  
> **DOKUNMA:** `app/lib/features/stats/**`, `core/stats/**`, `supabase/**`, `pubspec.yaml`

**Paralel:** Claude WP-65 e-posta · Codex WP-68 widget · Grok WP-66 retention (ayrı doc).

---

## 0. Demo özeti

| Alan | Öneri |
|---|---|
| Ürün soruları (en fazla 3) | S1 haftalık ritim · S2 ders dengesi · S3 gruba göre ben |
| Radar grafik | **İlk dilimde hayır** — mobil okunurluk zayıf; veri eksik eksen riski |
| İlk uygulama dilimi | **Haftalık ders dengesi yığılmış çubuk + tablo fallback** |
| Veri | Yalnız mevcut `study_sessions` + `subjects` (+ grup günlük stats) |
| Yeni metrik/RPC | Bu brief’te **yok**; yetmezse ayrı metrik WP |

---

## 1. Amaç

“Yeni grafik / radar” isteğini **karar hızlandıran** görsellere bağlamak. Güzel olduğu için grafik eklemek yasak (WP tuzakları). Her aday: hangi soruyu cevaplar, veri yeter mi, mobil/Windows, erişilebilir tablo.

---

## 2. Mevcut envanter (`Kodda doğrulandı`)

### 2.1 Metrik kaynağı

| Kaynak | Ne üretir |
|---|---|
| `study_sessions` | Süre, başlangıç günü (Europe/Istanbul), subject_id, live/manual |
| `study_stats.dart` | dailyTotals, lastNDays, streak, weekday/weekend, hour grid, averages |
| `canonical_stats_projection.dart` | today/week + version (UI/widget tutarlılığı) |
| Grup | `DailyStat` / `group_daily_totals` RPC → bugün sıralama, dönem toplamları |

Ayrı istatistik tablosu yok; her şey oturumdan türetilir.

### 2.2 Mevcut görseller (İstatistik sekmesi)

| Widget | Sekme | Soru (kabaca) |
|---|---|---|
| Dönem kartları (bugün/hafta/ay/yıl) | Kişisel | Ne kadar çalıştım? |
| Ortalama / hafta içi-sonu | Kişisel | Tempo dengeli mi? |
| `DailyBarChart` / `DailyLineChart` | Kişisel + Grup | Gün gün trend |
| `HourActivityChart` | Kişisel | Günün hangi saati? |
| `WeekHourHeatmap` / `StudyHeatmap` | Kişisel | Yoğunluk deseni |
| `SubjectDonut` | Kişisel | Ders payı |
| `SessionScatterChart` | Kişisel | Oturum uzunluğu dağılımı |
| `StudyRecords` | Kişisel | Rekorlar |
| Grup hedef + sıralama + bar/line | Grup | Kim / grup bugün |

**Boşluk (R2 adayları):** (1) tek bakışta “bu hafta ders dengesi zaman içinde”, (2) “ben vs grup medyanı” net kıyas kartı, (3) çok eksenli “çalışma profili” (radar — şüpheli).

---

## 3. Ürün soruları (en fazla 3)

WP: “kullanıcının cevaplamak istediği en fazla üç soru”. Aşağısı **önerilen set**; demo’da onay/değiştir.

| ID | Kullanıcı sorusu (TR) | Neden değerli | Mevcut veri yeter mi? |
|---|---|---|---|
| **S1** | “Bu hafta hangi günler zayıf kaldım?” | Ritmi düzeltir; hedef serisine bağlanır | Evet — dailyTotals + last 7 |
| **S2** | “Derslerim dengeli mi, yoksa tek derse mi yığıldım?” | Konu planı / denge | Evet — subject_id + süre (ders yoksa “Genel”) |
| **S3** | “Bugün / bu hafta gruba göre neredeyim?” | Sosyal motivasyon, abartısız | Kısmen — grup daily stats + kendi süre; **medyan** istemci hesaplanabilir |

**Onay kutuları (ürün):**

- [ ] S1+S2+S3 (**önerilen**)
- [ ] S1+S2 only (S3 gizlilik/ürün sonraya)
- [ ] Farklı 3 soru: _______________

---

## 4. Aday grafik karşılaştırması

Ölçüt: soru uyumu · veri yeterliliği · mobil ≤360dp · Windows ≥1008 · a11y tablo · uygulama maliyeti.

| Aday | Soru | Veri | Mobil | Windows | a11y | Maliyet | Karar |
|---|---|---|---|---|---|---|---|
| **A. 7-gün mini bar (kişisel özet üstü)** | S1 | ✅ | ✅ net | ✅ | Süre listesi | Düşük (mevcut bar reuse) | Dilim 0 polish |
| **B. Haftalık yığılmış çubuk (ders×gün)** | S2 | ✅ | Orta — max 5 ders rengi | ✅ panel | Gün×ders tablosu | Orta | **İlk R2 dilim** |
| **C. Radar (çok eksen profil)** | “profil” | ⚠️ eksen seçimi keyfi; az veri boş | ❌ küçük ekran | Orta | Zor | Yüksek | **R2-1 hayır** |
| **D. Ben vs grup medyanı (çubuk/çift)** | S3 | ✅ | ✅ kart | ✅ | 2 satır metrik | Düşük-orta | **İkinci dilim** |
| **E. Sparklines dashboard** | S1 | ✅ | ✅ | ✅ | Sayı | Düşük | WP-53/home ile çakışma riski; stats dışı |
| **F. Cumulative line (ay)** | tempo | ✅ | Orta | ✅ | Tablo | Düşük | Mevcut line ile örtüşür |

### 4.1 Radar neden ilk dilim değil?

1. Eksenler (süre, seri, ders çeşitliliği, sabah/akşam…) **ürün tanımı** ister; yoksa keyfi.  
2. 4–5 noktadan az veri → anlamsız çokgen.  
3. 360dp’de etiket çakışması; WCAG tablo/radar ikilisi pahalı.  
4. S2 yığılmış çubuk aynı “denge” cevabını daha dürüst verir.

Radar istenir ve onaylanırsa: **ayrı WP**, min. 4 hafta veri + sabit eksen sözleşmesi + tablo zorunlu.

---

## 5. İlk dilim (R2-1) — veri sözleşmesi

**Seçim (öneri):** Aday **B** — “Bu hafta ders dengesi”.

### 5.1 Girdi

| Alan | Kural |
|---|---|
| Zaman | Europe/Istanbul; `startOfWeek(today)` … `today` (Pzt–bugün) |
| Oturumlar | Kullanıcının kendi `study_sessions` |
| Ders | `subject_id` → ad; null → **“Ders yok”** |
| Üst N ders | Süreye göre en fazla **5** ders; kalan **“Diğer”** |
| Birim | Saniye (gösterim `formatHuman`) |

### 5.2 Çıktı modeli (uygulama WP’si için)

```text
WeekSubjectBalance {
  days: DateTime[7]           // Pzt…Paz (haftanın tam günleri; gelecek gün 0)
  subjects: { id, label, colorToken }[]  // ≤6 (5+Diğer)
  seconds[dayIndex][subjectIndex]: int
  empty: bool                 // tüm hafta 0
}
```

Saf fonksiyon: `core/stats` benzeri yerde (uygulama WP); **bu brief kod yazmaz**.

### 5.3 Görsel

| Yüzey | Davranış |
|---|---|
| Mobil | Dikey yığılmış bar (7 gün); legend altta 2 satır wrap; min dokunma 48dp legend |
| Windows (≥1008) | Sol grafik + sağ **tablo** (gün satır, ders sütun, satır toplamı) yan yana |
| Boş | “Bu hafta henüz kayıt yok — sayaçtan başla” (mevcut kişisel boş tona uyum) |
| Tek ders | Yığılmış değil düz bar; legend tek satır |
| Renk | Mevcut `subject_colors` token; sabit gri yok |

### 5.4 Erişilebilirlik

- Her gün için `Semantics`: “Pazartesi, Matematik 40 dk, Fizik 20 dk, toplam 1 sa”  
- `reduce-motion`: animasyonsuz bar  
- Kontrast: tema token (WCAG AA metin)  
- **Tablo fallback her zaman** (Windows’ta görünür; mobilde “Tablo” expansion)

### 5.5 RLS / gizlilik

- Yalnız **kendi** oturumları.  
- Grup üyelerinin ders kırılımı **yok** (R2-1).  
- S3 (ben vs grup) R2-2: yalnız **kendi süre + grup toplam/medyan sn**; isim listesi mevcut sıralama kartında kalır; e-posta yok.

---

## 6. Yerleşim eskizi (metin)

### Mobil (Kişisel sekme, üst sıra önerisi)

```
[ Dönem kartları 2×2 ]
[ S1: Son 7 gün bar — mevcut DailyBar özeti ]
[ S2: Bu hafta ders dengesi — YENİ yığılmış bar ]
[ Legend + "Tabloyu göster" ]
[ … mevcut heatmap / donut / saat … ]
```

### Windows

```
|  Dönem kartları (yatay)                         |
|  [Yığılmış bar ~60%]  |  [Gün×ders tablo ~40%] |
|  Mevcut grafikler iki sütun grid                 |
```

WP-53 desktop IA ile çakışmaması için R2-1 yalnız `PersonalStatsView` dilimi; shell değişmez.

---

## 7. Sonraki uygulama WP’si (plan iskeleti)

| WP (örnek ad) | Kapsam | DOKUNMA |
|---|---|---|
| **WP-67-A Stats R2-1** | `WeekSubjectBalance` saf fn + widget + tablo + test + golden | stats feature; pubspec yalnız fl_chart zaten varsa yeni paket yok |
| **WP-67-B** | S3 ben vs grup medyan kartı | grup stats; RLS genişletme yok |
| **WP-67-C** | Radar (yalnız §4 onayı + 4 hafta veri kuralı) | ayrı karar |

Bu brief **A/B/C kodunu yazmaz.**

---

## 8. Ürün onay kutuları

- [ ] Üç soru S1–S3 kabul  
- [ ] İlk dilim = yığılmış haftalık ders dengesi (**B**)  
- [ ] Radar R2-1’de yok  
- [ ] Tablo fallback zorunlu  
- [ ] Farklı ilk dilim: ________  

**Etiket:** envanter `Kodda doğrulandı`; seçim `Ürün kararı gerekiyor` (demo “goo/OK” ile varsayılanlar benimsenebilir).

---

## 9. Değişiklik günlüğü

| Tarih | Not |
|---|---|
| 2026-07-14 | WP-67 brief (Grok). Kod/grafik implementasyonu yok. |
