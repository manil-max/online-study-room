# Test Sistemi — katmanlar, kapılar ve bilinen boşluklar

> Bu belge **ne test edildiğini değil, neyin test EDİLMEDİĞİNİ** de yazar.
> Kalite kapısı sözleşmesi `docs/KALITE-PROGRAMI.md` ve `.agents/AGENTS.md §3`
> altındadır; burada o sözleşmeyi hangi mekanizmanın gerçekten uyguladığı
> anlatılır.

Son ölçüm: **2026-08-01**, `v56..HEAD` (88 commit, 247 dosya, +32k satır).

---

## 0. Bu sistemin dayandığı tek ders

**Yeşil bir kapı, kapının çalıştığını kanıtlamaz.**

Bu repo bunu üç kez pahalıya öğrendi:

| Olay | Ne oldu |
|---|---|
| l10n Gate | v55 boyunca kırmızıydı, kimse fark etmedi |
| `v8_critical_flows_test.dart` | Adı "kritik akışlar", **hiçbir kapıda koşmuyordu** (WP-465'te bağlandı) |
| WP-373 / WP-449 / `get_user_study_summary` | Dart ucu ile SQL ucu birbirinden habersiz kaydı; iki uç da yeşildi, **aradaki tel kopuktu** |

Bu yüzden bu sistemdeki her yeni kapının bir **self-test / probe adımı**
vardır: kapı bilerek bozulmuş bir girdiye kırmızı dönmüyorsa, kapı yoktur.

---

## 1. Katmanlar

| # | Katman | Nerede | Ne korur | Durum |
|---|---|---|---|---|
| 1 | Statik analiz | `flutter analyze` | Derleme/tip/lint | ✅ 0 uyarı |
| 2 | Birim + widget testleri | `app/test/**` (232 dosya) | Saf mantık, UI davranışı | ✅ 1399 test yeşil |
| 3 | Golden testleri | `--tags=golden` (Windows job) | Tema/görsel regresyon | ✅ |
| 4 | Entegrasyon | `app/integration_test/` (Windows job) | Kritik kullanıcı akışları | ✅ WP-465'te CI'a bağlandı |
| 5 | Veritabanı (pgTAP) | `supabase/tests/**` (44 dosya) | RLS, invariant, RPC davranışı | ✅ 647 assertion |
| 6 | **İstemci ↔ sunucu sözleşmesi** | `scripts/backend_contract_audit.py` | Dart/Edge çağrısı ile SQL imzasının kayması | 🆕 bu turda kuruldu |
| 7 | **Kapsam ratchet** | `scripts/coverage_audit.py` | Testsiz kodun sessizce girmesi | 🆕 bu turda kuruldu |
| 8 | l10n | `scripts/l10n_audit.py` | Katalog eşliği + gömülü metin | ✅ probe'lu |
| 9 | Deploy/release kapıları | `tooling/supabase/guard.tests.ps1`, `tooling/release/release-preflight.tests.ps1` | Yanlış ortama apply/release | ✅ 75+8, fail-closed |

Katman 1–4 ve 6–7 her push'ta `.github/workflows/ci.yml` içinde koşar.
Katman 5 `database-gates.yml`, katman 8 `l10n-gate.yml` altındadır.

---

## 2. Katman 6 — istemci ↔ sunucu sözleşme kapısı

```bash
python scripts/backend_contract_audit.py
```

**Neden var.** Dart testlerinin tamamı `InMemory*Repository` kullanır.
`Supabase*Repository` sınıflarının **hiçbiri hiçbir testte örneklenmez**
(22 dosyanın 22'si). pgTAP ise yalnız sunucu ucunu doğrular. Yani iki uç da
yeşilken aradaki çağrı kopuk olabilir ve bu **yalnız sahada** görünür.

**Ne doğrular** (91 çağrı ↔ 213 sunucu imzası):

1. `.rpc('ad')` — migration zincirinde bir karşılığı var mı
2. Gönderilen parametre kümesini kabul eden bir **overload** var mı, zorunlu
   parametreleri karşılanıyor mu
3. `.from('t').select('a, b')` — her sütun `t`'de gerçekten var mı

Dart **ve** Edge Function TypeScript'i birlikte taranır.

**Self-test.** `--self-test` geçici olarak tanımsız bir RPC ve olmayan bir
sütun ekler, kapının kırmızıya döndüğünü doğrular, probu siler. CI'da ayrı
adım olarak koşar.

**Bilinçli sınırlar** (yanlış pozitif kapıyı kullanılamaz kılar):
`params:` bir değişkense veya `...spread`/koşullu anahtar içeriyorsa çağrı
atlanır; argümansız `.select()` atlanır; view'lar sütun denetimine girmez.

> WP-472'nin `user_task` için elle yazdığı iki uçlu test bu kapının
> atasıdır ve **yerinde durur** — o test imza sırası, default'lar ve
> düşürülmüş eski overload gibi bu genel kapının bakmadığı ayrıntıları da
> doğrular. Genel kapı onun yerine geçmez, tabanını genişletir.

---

## 3. Katman 7 — kapsam ratchet

```bash
cd app && flutter test --exclude-tags=golden --coverage --dart-define-from-file=env.json
cd .. && python scripts/coverage_audit.py
python scripts/coverage_audit.py --top 30      # en riskli dosyalar
```

**Neden var.** Bu repoda **hiçbir kapsam ölçümü yoktu**. 1399 test yeşil
koşuyordu ama hangi kodun hiç çalıştırılmadığı bilinmiyordu — sekiz ajanın
paralel çalıştığı turlarda en tehlikeli boşluk budur.

**İlk ölçüm (2026-08-01):**

| Ölçü | Değer |
|---|---|
| Genel satır kapsamı | **%62.34** (21144/33918) |
| Kritik yollar | **%46.76** |
| Hiç dokunulmamış dosya | **54** |

Eşik `tooling/quality/coverage-baseline.json` içinde tutulur. Sabit bir hedef
(%80 gibi) yerine **ratchet** seçildi: mevcut gerçeği cezalandırmadan geriye
gidişi engeller. Eşik yalnız `--update-baseline` ile ve kapsamı bilerek
yükselten bir WP kapsamında güncellenir.

`flutter test --coverage` yalnız **import edilen** dosyaları enstrümante
eder; hiç import edilmemiş dosya lcov'da görünmez. Bu yüzden araç `app/lib`
ağacını ayrıca tarar ve bu dosyaları 0 kapsam sayar — aksi hâlde yüzde
olduğundan yüksek çıkar.

---

## 4. Bilinen boşluklar (kapatılmadı — bilerek yazılıyor)

| # | Boşluk | Risk | Not |
|---|---|---|---|
| G1 | **6 Edge Function'ın hiç testi yok** (1601 satır; `purge-accounts` kullanıcı verisi siler) | Yüksek | Sözleşme yüzeyi artık katman 6'da; **davranış** hâlâ testsiz |
| G2 | `Supabase*Repository` sınıfları %0 kapsam | Yüksek | Katman 6 çağrı sözleşmesini tutar; yanıt ayrıştırma/hata yolu testsiz |
| G3 | `alarm_providers.dart` %3.1 kapsam (317 satır) | Yüksek | Sayaç/alarm tarihsel olarak en çok hata çıkan alan |
| G4 | 54 dosyaya hiç dokunulmamış | Orta | Liste: `--top` |
| G5 | pgTAP yerel replay bu hostta koşmuyor (Docker) | Orta | CI'da koşuyor; yerelde `Replay bekliyor` etiketi |
| G6 | Mutasyon testi yok | Düşük | Kapı probe'ları bunun hedefli bir alt kümesi |

G1–G3 stable öncesi kapatılması gereken sıradadır.

---

## 5. Yerelde tam tur

```bash
python scripts/backend_contract_audit.py && python scripts/backend_contract_audit.py --self-test && python scripts/l10n_audit.py
```

```bash
cd app && flutter analyze && flutter test --exclude-tags=golden --coverage --dart-define-from-file=env.json
```

```bash
python scripts/coverage_audit.py
```
