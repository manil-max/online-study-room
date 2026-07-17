# Çoklu Cihaz Senkronizasyon QA ve Kurtarma Provası (WP-64)

> **Amaç:** Aynı test hesabıyla **2 Android + 1 Windows** üzerinde oturum, istatistik ve offline outbox davranışını uçtan uca kanıtlamak.  
> **Kapsam dışı:** Yeni senkron algoritması, şema/migration, production RLS değişikliği. Bulgu → ayrı debug WP.  
> **Kanıt etiketi (kabul):** `Cihazda doğrulanmalı` — emulator cihaz kanıtı sayılmaz.  
> **Kod referansları:** `Kodda doğrulandı` (davranış varsayımları; cihaz sonucu değildir).

---

## 0. Hızlı özet

| Alan | Karar |
|---|---|
| Cihaz seti | Android-A · Android-B · Windows-W (üçü zorunlu) |
| Hesap | Tek **test** hesabı; production kullanıcı yok |
| Build | Aynı sürüm adı + build numarası üçünde de kayda girer |
| Minimum senaryo | **12** (aşağıda MDS-01…MDS-14; en az 12 PASS) |
| P0 tanımı | Veri kaybı, çift oturum, yanlış kullanıcı verisi, kurtarılamaz outbox |
| P1 tanımı | Geçici tutarsızlık > hedef süre, UI yanlış toplam, recovery belirsiz |
| Bu WP kod yazar mı? | **Hayır** — yalnız bu belge + koşum/kanıt kaydı |

---

## 1. Kodda sabitlenen senkron davranışları (`Kodda doğrulandı`)

Cihaz koşumu bu varsayımları doğrular veya çürütür. Çürütme = bug bulgusu; bu WP içinde “düzeltme” yapılmaz.

| Davranış | Kaynak | Beklenen ürün sonucu |
|---|---|---|
| Oturum `id` istemci UUID | `study_providers.dart` (`Uuid().v4()`) | Her oturumun kalıcı kimliği cihazda doğar |
| Sunucu yazımı `upsert … onConflict: id` | `supabase_study_repository.dart` | Outbox yeniden denemesinde **çift satır yok** |
| Offline yazım → outbox kuyruğu | `offline_first_study_repository.dart` | Ağ yokken yerel cache + mutation; bağlantıda flush |
| Outbox sıra + hata da break | aynı dosya `flushPending` | İlk hata sonrası kuyruk kalır; sonraki denemede devam |
| Aynı `sessionId` mutation birleşimi | `offline_cache_store.dart` `_coalesceStudyMutation` | add+update → tek add (son hâl); add+delete → kuyruktan silinir |
| Remote + pending birleşimi | `_reconcileRemoteSessions` | Flush bitmeden realtime yerel outbox’ı ezmez |
| Gün sınırı | `istanbul_calendar.dart` (`Europe/Istanbul`) | “Bugün” tüm platformlarda İstanbul gününe göre |
| Canonical toplam | `canonical_stats_projection.dart` / `study_stats.dart` | Aynı oturum listesi → aynı toplam (UI tüketimi tutarlı olmalı) |
| Telemetri (opsiyonel) | `docs/archive/v8/OBSERVABILITY-V8.md` | `outbox_flush` / `realtime_snapshot` yalnız sayım; PII yok |

**Çoklu cihaz çakışma politikası (gözlem):** Aynı oturumu iki cihaz **eşzamanlı** düzenlerse sunucuda sürüm/CRDT yoktur; son başarılı ağ yazımı kalır (`update` by id). Bu “kayıp güncelleme” riski MDS-07’de ölçülür — istenen ürün politikası değilse ayrı tasarım/debug WP açılır.

---

## 2. Cihaz / sürüm / test hesabı matrisi

### 2.1 Cihaz kaydı (koşum öncesi doldur)

| Rol | Model | OS / One UI | Build (`version+build`) | Kurulum yolu | Not |
|---|---|---|---|---|---|
| **A** Android-A | | Android __ / One UI __ | | Play / sideload APK | Birincil telefon |
| **B** Android-B | | Android __ / One UI __ | | aynı paket | Tablet veya 2. telefon |
| **W** Windows-W | | Windows 11 __ | aynı `version+build` tercih | debug/release exe | WP-27 base veya yayımlı masaüstü |

**Sürüm kuralı:** Üç cihazda da `pubspec` / Ayarlar’daki sürüm satırı kayda yazılır. Farklı build ile koşum yapılacaksa tabloya **bilinçli sapma** notu düşülür; sonuçlar “karışık build” olarak etiketlenir.

**Önerilen Android yayımlı referans:** son yayımlı stable/beta (`1.0.x+N`). Windows: mevcut shell (WP-27); WP-53 Design 2.0 ürün kabulü açık olsa bile **senkron regressiyonu** base shell ile koşulabilir — sonuçlar “WP-53 IA öncesi/sonrası” diye ayrılır.

### 2.2 Test hesabı

| Alan | Değer (redakte) |
|---|---|
| E-posta | `qa-multi-device-***@…` (gerçek PII kanıta yazılmaz) |
| Grup | Test grubu (yalnız QA üyeleri) |
| Ön-temizlik | Koşum öncesi **bilinen** oturum seti: ya sıfır ya snapshot listesi (id + süre) |
| Yasak | Production kullanıcı, service_role, canlı token ekran görüntüsü |

### 2.3 Ağ kontrol araçları

| Platform | Öneri |
|---|---|
| Android | Uçak modu **veya** Geliştirici seçenekleri → Ağ kısıtlama; Wi‑Fi/veri birlikte kes |
| Windows | Adaptör devre dışı / `Firewall` engeli / “uçak modu” eşdeğeri |
| Ortak | Koşum videosunun başında saat + ağ durumu 3 sn gösterilir |

---

## 3. Ölçüm tanımları (PASS/FAIL netliği)

### 3.1 “Son durum eşleşir”

Üç cihaz online ve outbox boşken, aynı kullanıcı için:

1. **Oturum kümesi:** id seti aynıdır (eksik/fazla yok).  
2. **Alanlar:** her id için `start`, `end`, `duration_seconds`, `source`, `subject_id` aynıdır (±1 sn süre sapmasına izin **yok** — süre sunucu/alan değeri tam eşleşmeli).  
3. **Bugün toplamı:** Profil / Ana sayfa / İstatistik “bugün” saniyesi **aynı** (Europe/Istanbul günü).  
4. **Kayıt geçmişi sırası:** en yeni üstte; ilk 5 kayıt id sırası aynı.

### 3.2 Hedef süreler (regresyon eşiği)

| Olay | Hedef | Aşım |
|---|---|---|
| Online cihaz A’da oturum biter → B/W UI | ≤ **5 sn** (realtime) | P1 (geçici); 60 sn+ hâlâ yoksa P0 adayı |
| Offline oturum → ağ açılınca flush | ≤ **15 sn** (tek mutation) | P1; 3 deneme / yeniden aç sonrası kayıp → P0 |
| Uygulama soğuk açılış restore + sync | ≤ **10 sn** anlamlı liste | P1 |

### 3.3 Çift oturum

Aynı mantıksal çalışma için **iki farklı id** ve örtüşen zaman aralığı (kullanıcı tek oturum beklerken) → **P0**.  
İki cihazın bilinçli olarak iki ayrı oturum başlatması (MDS-09) beklenen çift kayıttır, P0 değildir.

### 3.4 Kanıt minimumu

Her senaryo için:

1. Video veya zaman damgalı ekran kaydı (başta cihaz rolü + build + ağ).  
2. Son durumda A/B/W’den **bugün toplamı** ve ilgili oturum satırı (PII redakte).  
3. PASS/FAIL + süre notu.  
4. FAIL ise §6 kurtarma adımı denendi mi? Sonucu?

Kanıt dosya adı önerisi: `mds64_<ID>_<rol>_<YYYYMMDD-HHMM>.mp4` (yerel; repoya ham video zorunlu değil — yol/link tabloda).

---

## 4. Senaryo kataloğu (≥12)

**Ortak önkoşul:** Üç cihaz aynı test hesabına giriş yapmış; saat dilimi cihazı ne olursa olsun uygulama “bugün”ü İstanbul’a göre gösterir (`Kodda doğrulandı`).

| ID | Senaryo | Adımlar (özet) | Beklenen (ölçülebilir) | A | B | W | Kanıt yolu | Sonuç |
|---|---|---|---|---|---|---|---|---|
| **MDS-01** | Online A → B+W yansıma | A’da 2 dk canlı oturum bitir; B ve W’yi ön planda tut | ≤5 sn içinde aynı id + süre; bugün toplamı +120 sn | [ ] | [ ] | [ ] | | |
| **MDS-02** | Online W manuel oturum → A+B | W’de manuel 15 dk oturum ekle | A+B listede tek satır; süre 900 sn; çift yok | [ ] | [ ] | [ ] | | |
| **MDS-03** | Offline A ekle → online flush | A uçak modu; 10 dk manuel ekle; uçak kapat | Flush sonrası **tek** satır tüm cihazlarda; id A’dakiyle aynı | [ ] | [ ] | [ ] | | |
| **MDS-04** | Offline W ekle → online flush | W ağ kes; 20 dk manuel; ağ aç | MDS-03 ile aynı; Windows outbox boşalır | [ ] | [ ] | [ ] | | |
| **MDS-05** | Offline add+update coalesce | A offline; oturum ekle; aynı oturumu düzenle (süre 30→45 dk); online | Sunucuda **tek** satır 45 dk; outbox’ta iki mutation kalmaz | [ ] | [ ] | [ ] | | |
| **MDS-06** | Offline add+delete coalesce | A offline; ekle; sil; online | Hiçbir cihazda o id yok; spuri delete hatası yok | [ ] | [ ] | [ ] | | |
| **MDS-07** | Eşzamanlı düzenleme (çakışma gözlemi) | Aynı online oturumu A 25 dk, B 40 dk yapıp ~aynı anda kaydet | Son durum **tüm** cihazlarda **tek** süre (ya 25 ya 40); iki satır yok. Hangi cihaz kazandı kayda yaz. Kayıp alan varsa P1/P0 §7 | [ ] | [ ] | [ ] | | |
| **MDS-08** | A siler, B önbellekte görür | A online siler; B 30 sn önce açılmış kalsın | B ≤5–15 sn içinde satırı kaybeder; yeniden açınca da yok | [ ] | [ ] | [ ] | | |
| **MDS-09** | İki cihaz eşzamanlı canlı oturum | A ve B aynı anda 3’er dk çalıştırıp bitir | **İki** ayrı id kalır; toplam +360 sn; “yanlış birleştirme” yok | [ ] | [ ] | [ ] | | |
| **MDS-10** | Process death / yeniden açılış | A offline + pending mutation varken force-stop → aç → online | Pending kaybolmaz; flush sonrası tek yazım; çift yok | [ ] | [ ] | [ ] | | |
| **MDS-11** | Gün sınırı 23:59→00:01 | Saat/cihazı güvenli test yoluna al **veya** sınır saatinde koş; oturum bitişi 00:01 İstanbul sonrası | “Bugün” toplamı yeni güne geçer; dünün satırı dünde kalır; A=B=W aynı gün anahtarı | [ ] | [ ] | [ ] | | |
| **MDS-12** | İstatistik yüzey tutarlılığı | MDS-01…04 sonrası: Ana sayfa bugün + Profil geçmiş + İstatistik özeti | Üç yüzeyde bugün sn **eşit**; W ile A farkı 0 | [ ] | [ ] | [ ] | | |
| **MDS-13** | Ağ flap sırasında update | A online oturumu düzenlerken ağ 5 sn kes–aç tekrarı (3 kez) | Son hâl tek; outbox boş veya bir kez flush; çift yok | [ ] | [ ] | [ ] | | |
| **MDS-14** | Uzun offline → soğuk açılış | A offline 30+ dk + 1 oturum; app kapat; online iken soğuk aç | ≤10 sn anlamlı liste; flush; B/W ile eşleşme | [ ] | [ ] | [ ] | | |

**Minimum kabul koşumu:** MDS-01…12 zorunlu. MDS-13/14 önerilir (güvenilirlik).

### 4.1 İsteğe bağlı (regresyon genişletme)

| ID | Senaryo | Not |
|---|---|---|
| MDS-15 | Grup sıralaması / günlük trend | Aynı test grubu; üye toplamları A vs W |
| MDS-16 | Presence (çalışıyor/mola) | Presence outbox ayrı kuyruk; oturum P0’ından bağımsız P1 |
| MDS-17 | Widget (yalnız Android) | WP-63 kapsamı; burada yalnız “session sonrası widget bugün” smoke |

---

## 5. Koşum prosedürü (operatör)

### 5.1 Hazırlık (15 dk)

1. Üç cihazda çıkış/giriş ile taze oturum; aynı hesap.  
2. Bildirim/izin diyaloglarını bir kez temizle (senkron ölçümünü bozmasın).  
3. Baseline snapshot: her cihazda “bugün sn” ve son 3 oturum id’sini yaz.  
4. Telemetri açıksa (`SENTRY_*`) yalnız sayım breadcrumb beklenir — PII denetimi ayrı (WP-47).  
5. Kronometre/saat videosu: yerel saat + “Europe/Istanbul günü” notu.

### 5.2 Senaryo koşumu

1. Tablodaki sırayla git; bağımlı senaryoları (MDS-12, MDS-07) temiz listede koş.  
2. Her senaryoda **tek değişken** (ağ veya eşzamanlılık); diğer cihazlar gözlemci.  
3. PASS değilse §6 kurtarmayı uygula; hâlâ FAIL → §7 bulgu kartı; **kod düzeltme yok**.  
4. Gün sınırı (MDS-11) gece koşumu veya kontrollü cihaz saati — production saati bozulmasın diye test cihazı tercih.

### 5.3 Kapanış

1. Outbox’un boş olduğunu dolaylı doğrula: offline eklenen her id online tüm cihazlarda.  
2. Test oturumlarını sil (opsiyonel temizlik) — silme de MDS-08 ile uyumlu senkron olmalı.  
3. Bu belgedeki sonuç özeti + P0/P1 listesini `progress.md` WP-64 notuna işle (yalnız Grok lane).

---

## 6. Güvenli kurtarma playbook (kullanıcıya uygulanabilir)

Amaç: veri kaybını durdurmak ve tekrar üretilebilir durum oluşturmak. **service_role / SQL Editor production** bu provada yok.

### 6.1 Genel sıra (her sapmada)

| Adım | Eylem | Başarı ölçütü |
|---|---|---|
| R1 | Tüm cihazlarda ağı stabilize et (Wi‑Fi açık, uçak kapalı) | Bağlantı ikonu normal |
| R2 | Uygulamayı **ön plana** al; 15 sn bekle (flush + realtime) | Listeler hareket eder / güncellenir |
| R3 | Soğuk yeniden başlat (force-stop → aç) **önce en güncel görünen cihazda** | Cache + outbox yeniden flush |
| R4 | Diğer cihazlarda pull-to-refresh yoksa soğuk açılış | id seti hizalanır |
| R5 | Hâlâ fark: **kaynak gerçeği** = en çok online flush tamamlamış cihazın listesi + (mümkünse) başka cihazda manuel karşılaştırma | Fark id’leri not edilir |
| R6 | Çift id şüphesi: aynı zaman aralığında iki satır → **silme yapma** önce bulgu; yanlış silme kaybı büyütür | Ekran kaydı |
| R7 | Kullanıcı mesajı (TR): “İnterneti açıp uygulamayı kapatıp açın; sorun sürerse destek/test kaydı açın — oturumları silmeyin.” | Uygulanabilir adım var |

### 6.2 Senaryoya özel

| Durum | Kurtarma |
|---|---|
| Offline eklenen oturum hiç gelmedi | R1–R3; hâlâ yoksa P0 “outbox kaybı”; cihaz model + adımlar |
| Çift oturum | Silmeden önce iki id’yi kaydet; hangisinin “doğru” süre olduğunu video ile işaretle; silme ürün kararı / debug WP |
| MDS-07 kayıp güncelleme | Beklenen risk; hangisinin kazandığını yaz; politika değişikliği ayrı WP |
| Windows listesi eski, Android yeni | W soğuk açılış; hâlâ eskiyse realtime abonelik P1 |
| Gün yanlış | Cihaz TZ vs Istanbul; “bugün” kartını üç cihazda aynı dakikada fotoğrafla |

### 6.3 Operatör güvenliği

- Production hesaba geçme.  
- `env.json` / token ekranda kalmasın.  
- Test verisini silerken önce senkronun oturduğunu doğrula (silinen id diğerlerinde de yok).

---

## 7. Bulgu → ayrı debug WP şablonu

Bu WP içinde fix yok. Her P0/P1 için `progress.md` Planlanan bölümüne (veya kullanıcı onayıyla) ayrı kart:

```markdown
### WP-XX: [Sync debug] <kısa ad>
- **Tetik:** WP-64 · MDS-0N · P0|P1
- **Problem:** <ölçülebilir sapma>
- **Tekrar:** <cihaz/build/ağ adımları>
- **Beklenen:** <§3 tanımı>
- **Gözlenen:** <A/B/W farkı>
- **Kanıt:** <dosya yolu / tarih>
- **Hipotez (kod okuma, fix değil):** örn. outbox flush sırası / realtime ezme / Windows lifecycle
- **SAHİP (sonraki WP):** ilgili repository / provider dosyaları — bu kart planlanınca netleşir
- **DOKUNMA şimdi:** production veri
```

### 7.1 Önem sınıfları

| Seviye | Örnek | Yayın etkisi |
|---|---|---|
| **P0** | Veri kaybı; çift oturum; başka kullanıcının verisi; outbox kalıcı kayıp | Stable/beta “çoklu cihaz” iddiası durur |
| **P1** | >60 sn tutarsızlık; stats yüzeyi farklı toplam; recovery belirsiz | Workaround + tarih olmadan kapanmaz |
| **P2** | Kozmetik sıra farkı, animasyon gecikmesi | Sonraki polish |

---

## 8. Koşum kaydı (özet form)

| Alan | Değer |
|---|---|
| Tarih (Europe/Istanbul) | |
| Operatör | |
| Build A/B/W | |
| Test hesabı (redakte) | |
| Zorunlu senaryo PASS sayısı | __ / 12 |
| P0 adedi | |
| P1 adedi | |
| Ürün sahibi kabulü | [ ] Evet / [ ] Hayır / [ ] Bekliyor |
| Not | |

### 8.1 Senaryo skor kartı (hızlı)

| ID | PASS | FAIL | Atlandı | Not |
|---|---|---|---|---|
| MDS-01 | | | | |
| MDS-02 | | | | |
| MDS-03 | | | | |
| MDS-04 | | | | |
| MDS-05 | | | | |
| MDS-06 | | | | |
| MDS-07 | | | | |
| MDS-08 | | | | |
| MDS-09 | | | | |
| MDS-10 | | | | |
| MDS-11 | | | | |
| MDS-12 | | | | |
| MDS-13 | | | | |
| MDS-14 | | | | |

---

## 9. Kabul kontrol listesi (WP-64)

- [ ] Cihaz matrisi §2 dolduruldu (model + OS + build).  
- [ ] En az **12** senaryo koşuldu; her biri için A/B/W son durum eşleşmesi kaydı var.  
- [ ] Veri kaybı / çift oturum **P0 = 0** (veya her P0 için ayrı debug WP açıldı ve ürün sahibi bilinçli risk kabul etti).  
- [ ] Başarısız ağ senaryolarında §6 kurtarma adımları denendi ve kullanıcı dilinde yazıldı.  
- [ ] Kanıtta token/e-posta/ham production veri yok.  
- [ ] Emulator-only koşum **yok**.  
- [ ] Ürün sahibi bu belgedeki özet formu imzalı kabul etti → ancak o zaman “Ürün kabulü geçti”.

**Ajan limiti:** Bu pakette kod + şablon `Kodda doğrulandı` seviyesine kadar tamamlanabilir. Cihaz videosuz “tamamlandı” iddiası **yasak**.

---

## 10. İlişkili belgeler

| Belge | İlişki |
|---|---|
| `docs/archive/v8/QA-V8-ANDROID.md` | Tarihsel tek cihaz Android smoke (V8-08/09 kısmi örtüşme) |
| `docs/archive/v8/OBSERVABILITY-V8.md` | Tarihsel outbox/realtime breadcrumb sözleşmesi (PII’siz) |
| `docs/KALITE-PROGRAMI.md` §8.2 | Canonical projection / senkron kabul |
| WP-43 (tamamlandı) | In-app projection temeli; bu WP çoklu cihaz kanıtı |
| WP-53 | Windows IA; senkron koşumu base shell ile de yapılabilir |

---

## 11. Değişiklik günlüğü

| Tarih | Not |
|---|---|
| 2026-07-14 | WP-64 ilk taslak: matris, 14 senaryo, kurtarma, bulgu şablonu. Kod/şema yok. Cihaz koşumu açık. |
