---
name: worker
description: >
  Bir Faz/WP'yi birinci sınıf kalitede uygulayan ajan. Kullanıcı "worker'ı oku ve
  şu Fazı/WP'yi yap" deyince tetiklenir. Basit tetik, altında derin kalite ve
  çakışma protokolü.
---

# Uygulayıcı Ajan Rehberi (Kalite Programı)

> Çekirdek kurallar `.agents/AGENTS.md`'de; kanonik program `docs/KALITE-PROGRAMI.md`'de.
> Burası **nasıl** uygulanacağının titiz rehberidir. Bu skill, kullanıcının basit
> promtunun altındaki derin iş akışıdır.

## Tetik

Kullanıcı (kısa): **"worker'ı oku ve V8-A'yı / WP-N'yi yap"** (Faz veya WP olabilir).

---

## Akış (özet)

```
1. progress.md oku            → kendi lane + verilen Faz/WP kartı
2. AGENTS.md + KALITE-PROGRAMI → kural + kabul kriterleri + DoD
3. ÇAKIŞMA ÖN-KONTROLÜ (Adım 0) → gerekiyorsa DUR ve UYAR
4. CLAIM et                   → Aktif Çalışma Kaydı'na kendi lane'ini yaz (iki-aşamalı)
5. Tasarım/teknik tasarımı netleştir → belirsizlik varsa sor
6. Adımları sırayla uygula    → yalnız SAHİP dosyalara yaz, DoD'yi izle
7. Doğrula                    → analyze 0 uyarı + test + (mümkünse) cihaz kanıtı
8. Kapat + LANE'İ BIRAK       → cihaz/demo gerekiyorsa kartı "Test için bekleyenler"e taşı
                                ve lane'i boşalt; tam bittiyse Tamamlanan'a; her hâlde commit
```

---

## Adım 0 — Çakışma Ön-Kontrolü (kod yazmadan ÖNCE, zorunlu)

`.agents/AGENTS.md §1.2`'yi uygula:

1. **Tüm Aktif Çalışma Kaydı'nı oku** (her lane).
2. Verilen görevin **SAHİP yolları + ortak/riskli yüzeyini**, diğer aktif lane'lerin SAHİP/ortak yüzeyi ve §1.4 sıcak dosyalarıyla karşılaştır.
3. Şu durumlardan biri varsa **BAŞLAMA, kullanıcıyı somut ve gerekçeli uyar:**
   - SAHİP yol kesişimi · ortak sıcak dosya · aynı/çakışan migration · büyük program (Saat/Tema/Başarım) eşzamanlılığı · henüz kabul edilmemiş bir WP'ye bağımlılık.
4. Uyarı, hangi lane/WP ile, hangi dosyada, **neden** sorun olacağını ve **somut öneri** (serileştir / kapsamı daralt / farklı WP) içerir. Örnek şablon `AGENTS.md §1.2`'de.
5. Çakışma yoksa → CLAIM (Adım 1) → kaydı **yeniden oku** → hâlâ temizse başla.

> **Kullanıcı görevi sana açıkça vermiş olsa bile bu kural geçerlidir.** "Bana verildi" çakışmayı geçersiz kılmaz — çakışma görürsen BAŞLAMA, uyar, onay bekle. Emin değilsen çakışma **var** say ve sor. "Belki sorun olmaz" ile başlama.

---

## Adım 1 — CLAIM + dal aç (başlamadan önce)

1. **Dal aç:** `git switch -c wpNN-kisa-ad` (AGENTS.md §1.5). Tüm commit'ler bu dala gider; `main`'e sen merge etmezsin.
2. `progress.md` Aktif Çalışma Kaydı'nda kendi lane'ini doldur (format `AGENTS.md §1.1`): Durum `[~] Aktif`, Faz/WP, Aşama `Geliştiriliyor`, **SAHİP yollar**, **ortak/riskli yüzey**, **Dal: `wpNN-kisa-ad`**, başlangıç + son güncelleme (Europe/Istanbul), not. Güncel sürüm/faz etiketini koru; eski plan metnini geri getirme.

---

## Kalite Barı (bu programın özü)

Her WP birinci sınıf çıktı üretir. Uygularken:

- **Kabul kriterleri ölçülebilir.** "Güzel/profesyonel" değil; "oturum sonrası UI ≤ 1 sn'de güncellenir", "sayaç 8 saatte ≤ ±1 sn sapar" gibi (KALITE-PROGRAMI §4.4). Kart kabul kriteri belirsizse **netleştir, gerekirse sor.**
- **Ölü anahtar yasak.** Eklediğin her düğme/ayar gerçekten çalışır.
- **Referans kıyası.** Kıyaslanan davranışı (ör. Google Saat alarm akışı) referans al, birebir kopyalama — Odak Kampı kimliğiyle özgün yap.
- **Platform sınırlarına saygı.** Bildirim görünümü OEM'e bağlıdır; widget < 15 dk periyodik güncelleme garanti değildir → canlı süre için native `Chronometer`, state için receiver/service, stats widget'ları **olay bazlı**. Saniyede bir Flutter yeniden çizme yok.
- **Boş/hata/çevrimdışı** her ekranda düşünülür.

---

## Kod Kuralları (özet — tamamı AGENTS.md'de)

- `cd app`; her `run/test/build`'e `--dart-define-from-file=env.json`; `analyze` bayraksız.
- Repository **çift**: `supabase/` + `in_memory/` birlikte.
- Migration `NNNN_ad.sql` sıralı; RLS zorunlu; **XP/kritik ilerleme server-authoritative**; sır istemcide yok.
- Kullanıcı metni Türkçe; gün sınırı Europe/Istanbul tek yardımcıdan.

---

## Lane & progress.md Yaşam Döngüsü

`progress.md` plan listesi değil, **canlı durum kaynağıdır.** Her durum değişiminden hemen önce dosyayı yeniden oku; yalnız **kendi lane + kendi WP kartına dar patch** uygula. Tüm dosyayı stale kopyadan yeniden yazma; başka ajanların kartlarını ve güncel faz etiketlerini koru.

- Üç+ canlı lane: `Gemini`, `Claude`, `Codex` (+ gerekirse ek). Yalnız kendi lane.
- Anlamlı her geçişte (başlat / blokla / devret / **test için parka al** / tamamlandı) `progress.md` anında güncellenir.
- **Aktif Çalışma Kaydı yalnız GERÇEKTEN yazılan işi tutar.** Kod bitip cihaz/demo bekleyen kart aktifte kalmaz → `## Test için bekleyenler`e taşınır, lane boşalır. Aktif lane = o an dosya yazan ajan demektir; başkası ona göre çakışma hesaplar.
- Handoff: WP başka ajana geçiyorsa tek editte yeni lane'e taşınır + kısa handoff notu.

---

## WP Bitirme Sırası

Tüm adımlar `[x]` olduğunda:

### 1. Doğrula
```bash
cd app
flutter analyze                       # 0 uyarı (bayraksız)
flutter test                          # yeşil
flutter test --tags golden            # tema/görsel değiştiyse
```
Hatayla **commit atma** — önce düzelt. Mümkünse gerçek cihaz kanıtı (ekran görüntüsü/video) topla.

### 2. Durumu güncelle + LANE'İ BIRAK (iki olasılık)

> **Altın kural:** İş bitince lane'ini **aktif** bırakma. Aktif kalan lane diğer worker'ları çakışma gerekçesiyle bloklar ve "en basit WP bile tekte kapanmaz". İki yol da lane'i boşaltır.

- **Cihaz QA + ürün kabulü VARSA (tam bitti):** kartı diğer başlıklardan kaldır → `## Tamamlanan İş Paketleri` altına ekle (kapsam + değişen dosyalar/ne yapıldı/test/kanıt). Lane: `Durum: [x] Boşta`, `Aktif WP: —`. Aynı WP iki başlıkta **asla** bulunmaz.

- **Kod+otomatik test bitti ama cihaz QA / ürün demosu gerekiyor (EN SIK DURUM):**
  1. Kartı **Aktif Çalışma Kaydı'ndan çıkar** → `## Test için bekleyenler` bölümüne taşı: özet + **ne bekleniyor** (cihaz/demo) + son commit/dal + kanıt etiketi `Cihazda doğrulanmalı`. Üstteki özet tablosuna da bir satır ekle.
  2. **Kendi lane'ini boşalt:** `Durum: [x] Boşta`, `Aktif WP: —`.
  3. Bu bölüm **aktif çalışma DEĞİLDİR** — kimse claim etmez, başka WP'yi engellemez. Böylece bir sonraki worker çakışma ön-kontrolünde bu WP'yi "test bekliyor" görür, üstünden geçer ve **hemen yeni işe başlar**.
  4. Kabul gelince kart **Tamamlanan**'a taşınır; cihazda bug çıkarsa **ayrı debug WP** açılır (aynı kartı diriltme).

> Yani "işi bitirmek" = lane'i serbest bırakmak. Testi sen beklemezsin; parka koyar, çıkarsın.

### 3. Commit (kendi dalına)
```bash
git add -A
git commit -m "WP-N: [kısa açıklama]"   # wpNN-kisa-ad dalında
```
**Push yok** (istenmedikçe). WP başına **tek commit**. **`main`'e merge ETME** — WP "Ürün kabulü"nden geçince kullanıcı birleştirir (AGENTS.md §1.5). Kullanıcıya dal adını bildir.

### 4. Teslim özeti (kullanıcıya)
Kısa Türkçe: ne yapıldı · değişen dosyalar · test durumu · **hangi kanıt etiketi** (Kodda doğrulandı / Cihazda doğrulanmalı) · varsa uygulanması gereken migration · açık kalan `Ürün kararı`.

---

## Karar Alma

- Küçük teknik karar (değişken adı, widget seçimi) → kendin al, devam et.
- Belirsiz kabul kriteri / birden çok yaklaşım / geri dönüşü zor karar → `progress.md`'ye `⚠️ Soru` yaz, **dur ve sor** (`Ürün kararı gerekiyor`).
- Migration/RLS/güvenlik etkisi olan karar → asla tek başına "idare eder" deme; AGENTS.md §2 güvenlik kurallarına göre değerlendir, gerekirse sor.

---

## Sık Tuzaklar

| Tuzak | Çözüm |
|---|---|
| Çakışma ön-kontrolünü atlamak | Adım 0 zorunlu — başlamadan tüm Aktif Kayıt okunur |
| `analyze`'e `--dart-define-from-file` vermek | analyze bu bayrağı kabul etmez; bayraksız çalıştır |
| Tek repo implementasyonu güncellemek | `supabase/` + `in_memory/` birlikte |
| XP/başarıyı istemcide yazmak | Server-authoritative; ledger + idempotent event |
| `fromMap`'te kaldırılmış kolon | `grep -rn "kolon" app/lib` ile kalıntı ara |
| Migration sırası | Son numarayı `supabase/migrations/` dizininden oku |
| Presence `group_id` | KORUNUYOR — dokunma |
| Sıcak dosyaya (pubspec/theme/main) sessiz giriş | WP'de yazılı değilse dur ve sor |
