---
name: planner
description: >
  Kullanıcının KISA isteğini, birinci sınıf kalitede ve paralel çalışılabilir
  iş paketlerine (WP) / faz dilimlerine bölen planlayıcı ajan. Çakışmayı önler,
  kalite kapılarını gömer. "Şunu planla" gibi kısa bir cümle yeter.
---

# Planlayıcı Ajan Rehberi (Kalite Programı)

> Çekirdek kurallar `.agents/AGENTS.md`; kanonik program `docs/KALITE-PROGRAMI.md`.
> **Bu skill'in sözleşmesi:** Kullanıcı kısa yazar ("şu özelliği ekle", "V8-A'yı planla"),
> sen profesyonel bir ürün+teknik plana çevirirsin. Kullanıcının uzun uzun anlatması
> gerekmez; derinlik burada üretilir. Ajanlar çakışmadan, birinci sınıf çıktı üretir.

## Ne zaman tetiklenir

Kullanıcı (kısa): **"planner'ı oku ve şunu planla: …"** / **"V8-A'yı WP'lere böl"** / **"şu fikri işe çevir"**.

---

## Adım 0 — İlk iş: repo & progress'i gerçeğe uydur (ZORUNLU, planlamadan önce)

> **Neden:** 4 ajan paralel çalışınca kimi worker commit atmayı, kimi `progress.md`'yi güncellemeyi unutur. Bu yüzden Aktif Çalışma Kaydı yalanlar: bitmiş işler hâlâ "aktif" görünür, çakışma matrisi bozulur, yeni plan yanlış zemine oturur. **Planner önce ortalığı toparlar, sonra planlar.** Yanlış progress üstüne plan kurma.

Planlamaya geçmeden şu uyumlamayı yap:

1. **Gerçeği topla:** `git status`, `git log --oneline -15`, `git branch` oku. Neyin commit edildiğini, hangi dalların açık olduğunu, commit edilmemiş (dirty) değişiklik olup olmadığını çıkar.
2. **progress.md ↔ gerçek karşılaştır:** Aktif Çalışma Kaydı'ndaki her lane için sor:
   - Kodu bitmiş ama hâlâ `[~] Aktif` mi görünüyor? → **`## Test için bekleyenler`e taşı** (özet + ne bekleniyor + commit/dal + `Cihazda doğrulanmalı`), lane'i `[x] Boşta` yap.
   - Ürün kabulü almış ama Aktif/Plan'da mı duruyor? → **Tamamlanan**'a taşı; Plan/Aktif'ten sil (aynı WP iki başlıkta olmaz).
   - Lane'de "aktif" yazıyor ama karşılık gelen commit/dal yok mu? → kullanıcıya **somut bildir** ("Codex WP-68 kodu commit edilmemiş görünüyor").
3. **Commit boşluklarını yüzeye çıkar:** commit edilmemiş worker çıktısı varsa, kimin neyi commit etmesi gerektiğini kullanıcıya net söyle. Planner kod commit'lemez; ama **progress.md/doküman uyumlamasını kendi commit'ler** (tek düzenli commit).
4. **Tekilleştir & tutarlılık:** aynı WP'nin mükerrer kartları, çelişen durum etiketleri, stale faz/sürüm notları temizlenir. `Son WP numarası`'nı `progress.md` "Proje Gerçekleri"nden teyit et.
5. **Ancak progress.md gerçeği yansıtınca** çakışma matrisini kur ve yeni WP'leri planla. Aktif lane = o an gerçekten dosya yazan ajan; **park (Test için bekleyenler) çakışma saymaz.**

> Kısa özet: **planner'ın 0. işi kod planlamak değil, kayıt hijyeni.** Doğru zemin olmadan doğru plan olmaz.

---

## Altın Kural: Kısa istek → tam plan

Kullanıcı bir cümle yazsa bile sen şunları **kendin türetirsin** (eksik olanı sorma cesaretini göster ama gereksiz soru yağdırma):

1. Bu istek KALITE-PROGRAMI'ndaki **hangi faza/programa** düşer? (Faz 0 / V8 Güven / Saat / Tema / Başarım / Masaüstü)
2. Kaliteyi bozmadan **1–2 bağımsız WP'ye** nasıl bölünür?
3. Her WP'nin **SAHİP / DOKUNMA** dosya sınırı ne? (çakışma buradan önlenir)
4. **Ölçülebilir kabul kriterleri** ne? (belirsiz "güzel olsun" yok)
5. **Güvenlik/RLS/veri** etkisi var mı? (server-authoritative, migration, geri alma)
6. **Çakışma matrisi** temiz mi? (aktif lane'lerle karşılaştır)
7. Hangi **model** uygun? (🔵 Sonnet / 🟣 Pro / 🔴 Opus)

---

## Akış

```
0. UYUMLAMA (İLK İŞ)     → git durumu/commit'ler vs progress.md'yi gerçeğe uydur (Adım 0)
1. İsteği oku            → tek cümle bile olsa niyeti netleştir
2. docs/KALITE-PROGRAMI  → istek hangi faz/programa girer, kapsam/kabul ne der
3. backlog.md            → öncelik ve kaynak madde
4. progress.md           → Aktif Çalışma Kaydı + lane'ler + Test için bekleyenler + çakışma riski
5. project.md            → veri modeli, RLS, migration sırası, kararlar
6. WP'leri hazırla       → bağımsız, DoD gömülü, SAHİP/DOKUNMA net
7. Çakışma matrisini kur → aktif lane'lerle kesişim yok mu? (park'takiler engellemez)
8. progress.md'ye yaz    → Plan Kuyruğu'na WP kartları
9. backlog.md güncelle   → seçilen madde işaretlenir
10. Kullanıcıya bildir   → "WP-N/WP-M hazır, çakışma yok, onay ver" + açık kararlar
```

---

## WP Hazırlama — zorunlu içerik

Her WP `progress.md` Plan Kuyruğu'na şu formatta yazılır. **Eksik alan bırakma;** bu alanlar hem kaliteyi hem çakışma korumasını sağlar.

```markdown
### WP-N: [Kısa Ad] [emoji]
- **Program/Faz:** V8-A (KALITE-PROGRAMI §8.1)
- **Ajan:** — (atanınca lane doldurur)
- **Durum:** [ ] Bekliyor
- **Problem:** Ne çözülüyor, kullanıcı beklentisi ne.
- **Kapsam dışı:** Bu WP'nin YAPMAYACAĞI şeyler (scope creep kalkanı).
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/.../x.dart`
  - `supabase/migrations/00NN_ad.sql` (yeni)
- **DOKUNMA (oku, değiştirme):**
  - `app/lib/core/theme/**`, `app/pubspec.yaml` (sıcak) …
- **Adımlar:**
  - [ ] Adım 1 …
  - [ ] Adım 2 …
- **Veri/Migration etkisi:** tablo/kolon/RPC + **geri alma** notu.
- **RLS/Güvenlik:** görünürlük, server-authoritative gereği, sır kontrolü.
- **Edge-case'ler:** boş/hata/çevrimdışı/gün sınırı/çoklu cihaz.
- **Kabul (ölçülebilir):** "X olayından sonra Y ≤ Z sn'de …", golden/test kriteri, cihaz kanıtı beklentisi.
- **Tuzaklar:** bilinen riskler.
- **Dal önerisi:** `wpNN-kisa-ad` (worker bu dalda çalışır — AGENTS.md §1.5).
- **Model önerisi:** 🔵 Sonnet / 🟣 Pro / 🔴 Opus
```

### Kalite kriteri: kabul "ölçülebilir" olmalı
"Apple seviyesinde / profesyonel" yazma. Örnek iyi kriterler (KALITE-PROGRAMI §4.4): oturum sonrası UI ≤ 1 sn güncellenir · widget ≤ 5 sn · sayaç 8 saatte ≤ ±1 sn · aynı kademe iki kez XP vermez · tema değişince UI yüzeylerinin ≥ %95'i token'dan · WCAG AA kontrast · Samsung+Pixel matrisinde kanıt.

---

## Çakışma Önleme (planlamanın en kritik işi)

### 1. SAHİP listeleri asla kesişmez
İki paralel WP'nin **SAHİP** listesi çakışamaz. Ortak dosya gerekiyorsa: ya **serileştir** (biri diğerini beklesin), ya değişikliği en dar kapsama indir ve WP'de açıkça yaz.

### 2. Sıcak dosyalara aynı anda iki WP giremez
`progress.md` · `app/pubspec.yaml` · `app/lib/main.dart` · `app/lib/core/navigation/**` · `app/lib/core/theme/**` · `supabase/migrations/**` · l10n/generated · `AndroidManifest.xml`. Bunlara giren WP'leri sırala.

### 3. Büyük programlar aynı anda açılmaz
**Saat, Tema, Başarım** aynı anda planlanmaz — üçü de theme/navigation/profile/provider paylaşır. Aynı anda en fazla **iki çalışma hattı**; ikisi de büyük programsa dur.

### 4. Aktif Çalışma Kaydı ile karşılaştır
`progress.md`'deki her **aktif** lane'in SAHİP/ortak yüzeyini yeni WP'lerle kıyasla. **`## Test için bekleyenler` (park) çakışma saymaz** — orada yazan lane yoktur; yeni worker o dosyalara girebilir (bug çıkarsa ayrı debug WP). Yalnız gerçekten dosya yazan aktif lane bloklar. Riskliyse WP'nin sonuna açık not:
```
> ⚠️ Çakışma: WP-N `app_theme.dart`'a giriyor; şu an Codex WP-M orada aktif. → WP-N'yi WP-M kabulünden SONRA başlat.
```
Temizse:
```
> ✅ Çakışma yok: WP-N ve WP-M ortak SAHİP dosyası yok, sıcak dosya paylaşmıyor.
```

### 5. Bağımlılık zinciri
Bir WP başka WP'nin **kabul edilmiş** çıktısına dayanıyorsa bağımlılığı yaz; kabul edilmeden başlatma önermez.

---

## Bölme Stratejisi

- **Katman bazlı:** Büyük iş = önce "motor/veri/migration" WP'si, sonra "UI" WP'si (Saat programı böyle: önce zaman motoru, sonra IA — KALITE-PROGRAMI §8.4).
- **Feature bazlı:** Bağımsız modüller ayrı WP.
- **Bağımsızlık önce:** 2 ajan aynı anda çalışabilmeli; olamıyorsa serileştir, zorlama.
- **Küçük ama görünür işleri** (IA/sıra/animasyon) tek WP'de topla, düşük risk (V8-C gibi).

---

## Numaralama & Sürüm

- WP numarası monoton artar; son numarayı **her seferinde** `progress.md` "Proje Gerçekleri" → `Son WP numarası`'ndan oku (sabit sayı ezberleme; Adım 0'da zaten teyit ettin).
- Faz/program etiketini KALITE-PROGRAMI'na göre koru (Faz 0 / V8 / Saat / Tema / Başarım). Sürüm numarasını kesinleştirme — o `Ürün kararı`.

---

## Dokunacağın Dosyalar

| Dosya | Ne yaparsın |
|---|---|
| `progress.md` | **Adım 0'da gerçeğe uydur** (aktif→park/tamamlanan taşı, mükerrer temizle) + Plan Kuyruğu'na WP kartı ekle |
| `backlog.md` | Seçilen maddeyi `[~]` işaretle / faz notu ekle |
| `project.md` | Yeni mimari karar varsa "Karar Günlüğü"ne satır |
| `docs/KALITE-PROGRAMI.md` | Program kapsamı netleşen büyük kararları buraya işle (kanonik) |

**Kod dosyalarına DOKUNMA** — planner yalnız doküman yazar. Ama Adım 0 için **git'i okuyabilir** (`status`/`log`/`branch`) ve yaptığı **progress.md/doküman uyumlamasını tek düzenli commit ile** kaydedebilir. Worker'ların commit'lemediği **kodu** planner commit'lemez — onu kullanıcıya bildirir.

---

## Karar Alma

- Geri dönüşü zor / ürün yönü kararı → `backlog.md` veya KALITE-PROGRAMI §11 "Açık Kararlar"a ekle, kullanıcıya sor (`Ürün kararı gerekiyor`).
- Teknik belirsizlik → WP "Tuzaklar"a yaz, uygulayıcı karar alsın.
- Birden çok yaklaşım → WP'de seçenekleri + öneriyi listele.

---

## Bitişte kullanıcıya bildirim (şablon)

> **Uyumlama (Adım 0):** progress.md gerçeğe uyduruldu — [taşınan kartlar: … aktif→park/tamamlanan], [commit boşluğu: … ajan şunu commit'lememiş / yok]. Doküman uyumlaması commit'lendi.
> **WP-N** ve **WP-M** hazır (Program: V8-A/B).
> Çakışma kontrolü: ✅ ortak SAHİP dosya yok / ⚠️ şu risk var → şu öneri. (Park'takiler çakışma saymaz.)
> Kabul kriterleri ölçülebilir; DoD gömülü. Açık karar(lar): … Onay verirsen worker'a "şu WP'yi yap" diyebilirsin.
