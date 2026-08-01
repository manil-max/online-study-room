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
| 2 | Birim + widget testleri | `app/test/**` (240 dosya) | Saf mantık, UI davranışı | ✅ 1507 test yeşil |
| 2b | Android native JVM testleri | `app/android/app/src/test/**` | Kotlin servis/widget/prefs davranışı | ✅ `android-unit` ana tester kapısında |
| 3 | Golden testleri | `--tags=golden` (Windows job) | Tema/görsel regresyon | ✅ |
| 4 | Entegrasyon | `app/integration_test/` (Windows job) | Kritik kullanıcı akışları | ✅ WP-465'te CI'a bağlandı |
| 5 | Veritabanı (pgTAP) | `supabase/tests/**` (44 dosya) | RLS, invariant, RPC davranışı | ✅ 647 assertion |
| 6 | **İstemci ↔ sunucu sözleşmesi (statik)** | `scripts/backend_contract_audit.py` | Dart/Edge çağrısı ile SQL imzasının kayması | ✅ 91 çağrı, self-test'li |
| 6b | **Repository kablo testleri (çalışma zamanı)** | `app/test/support/supabase_wire_harness.dart` | RPC adı/yanıt ayrıştırma/hata eşlemesi | ✅ 20/22 repository |
| 7 | **Kapsam ratchet** | `scripts/coverage_audit.py` | Testsiz kodun sessizce girmesi | ✅ genel %65.23 / kritik %58.92 |
| 7b | **Edge Function tip denetimi + testleri** | `deno check` + `deno test` (CI job) | Sunucuda çalışan 1601 satırın derlenmemesi; purge yetkilendirmesi | ✅ 6/6 tip, 13 davranış testi |
| 8 | l10n | `scripts/l10n_audit.py` | Katalog eşliği + gömülü metin | ✅ probe'lu |
| 8b | **Migration zinciri + head pinleri** | `scripts/test_all.py --internal-migration-head` | Numara boşluğu, başlık kuralı, kontrat/guard head'inin ayrı düşmesi | ✅ 114 dosya kesintisiz |
| 9 | Deploy/release kapıları | `tooling/supabase/guard.tests.ps1`, `tooling/release/release-preflight.tests.ps1` | Yanlış ortama apply/release | ✅ 75+8, fail-closed |

Katman 1–4, 6, 6b, 7 ve 7b her push'ta `.github/workflows/ci.yml` içinde
koşar (beş iş). Katman 5 `database-gates.yml`, katman 8 `l10n-gate.yml`
altındadır.

---

## 2. Katman 6 — istemci ↔ sunucu sözleşme kapısı

```bash
python scripts/backend_contract_audit.py
```

**Neden var.** Bu kapı kurulmadan önce Dart testlerinin tamamı
`InMemory*Repository` kullanıyordu; 22 `Supabase*Repository` sınıfının
**hiçbiri hiçbir testte örneklenmiyordu**. pgTAP ise yalnız sunucu ucunu
doğrular. İki uç da yeşilken aradaki çağrı kopuk olabiliyordu ve bu
**yalnız sahada** görünüyordu. Statik kapı çağrının *şeklini*, katman 6b
kablo testleri *davranışını* doğrular — ikisi ayrı katmandır.

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

**Ölçüm (2026-08-01):**

| Ölçü | İlk ölçüm | Bu turdan sonra |
|---|---|---|
| Genel satır kapsamı | %62.34 | **%65.23** (22304/34191) |
| Kritik yollar | %46.76 | **%58.92** |
| Hiç dokunulmamış dosya | 54 | **33** |

Kritik yollar **10.2 puan** yükseldi: 20 repository'nin kablo testi
(`supabase_wire_*_test.dart`) ve `alarm_providers` durum makinesi
(`alarm_providers_wp466_test.dart`, %3.1 idi) eklendi.

Eşik `tooling/quality/coverage-baseline.json` içinde tutulur. Sabit bir hedef
(%80 gibi) yerine **ratchet** seçildi: mevcut gerçeği cezalandırmadan geriye
gidişi engeller. Eşik yalnız `--update-baseline` ile ve kapsamı bilerek
yükselten bir WP kapsamında güncellenir.

`flutter test --coverage` yalnız **import edilen** dosyaları enstrümante
eder; hiç import edilmemiş dosya lcov'da görünmez. Bu yüzden araç `app/lib`
ağacını ayrıca tarar ve bu dosyaları 0 kapsam sayar — aksi hâlde yüzde
olduğundan yüksek çıkar.

---

## 3b. Katman 7b — Edge Function kapısı

```bash
deno check --no-lock supabase/functions/<ad>/index.ts
deno test --no-lock --allow-env supabase/functions/
```

**Neden var.** Altı Edge Function (1601 satır, içinde kullanıcı verisini
kalıcı silen `purge-accounts`) **hiçbir yerde derlenmiyordu**. `deno check`
ilk kez koşturulduğunda altısı da düştü; gerçek bulgu, dört fonksiyonda
`catch` bloğunun `unknown` üzerinde `error.message` okumasıydı — `Error`
olmayan bir şey fırlatılsa istemciye **boş hata gövdesi** gidiyordu.

**Saf kararlar `_shared/` altındadır.** `index.ts` en üst seviyede
`serve(...)` çağırır; test onu import etseydi gerçek bir sunucu başlar ve
test asılırdı. `purge-accounts`'un yetkilendirme ve hata sınıflandırma
kararları `_shared/purge_policy.ts`'e çıkarıldı — `serve` kablolamasına
hiç dokunulmadan davranış test edilebilir oldu.

En kritik test: **yanlış secret 401 alır ve hiçbir secret tanımlı
değilse istek yine reddedilir** (fail-closed). Yanlış yapılandırılmış bir
ortamda purge herkese açık olmamalı.

---

## 4. Bilinen boşluklar (kapatılmadı — bilerek yazılıyor)

| # | Boşluk | Risk | Durum |
|---|---|---|---|
| G1 | Edge Function davranış testleri | Orta | 🟢 `purge-accounts` karar mantığı `_shared/purge_policy.ts`'e çıkarıldı ve 13 testle kapsandı (yetkilendirme fail-closed + hata sınıflandırma). Altısı da `deno check`ten geçiyor. **Kalan:** diğer beş fonksiyonun handler'ı hâlâ `serve()` içinde gömülü; davranış testi için aynı çıkarma deseni uygulanmalı |
| G2 | `Supabase*Repository` kablo testleri | Düşük | 🟢 **20/22**. Kapsanmayan ikisi: `report_attachment_upload` (yardımcı, dolaylı kapsandı) ve `supabase_presence_repository` (üç modlu, ağırlıklı realtime) |
| G3 | `alarm_providers.dart` | Düşük | 🟢 %3.1 → kapsandı. Odak: süre epoch'tan türetilir, önbellekten değil |
| G4 | 33 dosyaya hiç dokunulmamış (54'tü) | Orta | 🟡 Çoğu ekran/widget. Liste: `--top` |
| G5 | pgTAP yerel replay bu hostta koşmuyor (Docker) | Orta | 🔴 CI'da koşuyor; yerelde `Replay bekliyor` etiketi. **Host sınırı — kod değişikliğiyle kapatılamaz** |
| G6 | Realtime (`.stream()`) yolları | Düşük | 🟡 websocket taşır; http koşum takımı görmez. Bilinçli sınır |
| G7 | İki fiziksel cihaz + Android process/isolate yaşam döngüsü | Yüksek | 🔴 JVM/Dart testleri protokol ve saf projeksiyonu yakalar; OEM arka plan politikası, gerçek FCM ve iki cihaz görünürlüğü yalnız staging cihaz matrisiyle kanıtlanabilir. WP-482'nin kalan kapısı |

### Yeni bir Supabase repository testi nasıl yazılır

`app/test/data/supabase_wire_contract_test.dart` şablondur. Koşum takımı
`SupabaseClient`'a sahte bir http istemcisi verir; böylece **gerçek**
PostgREST sorgu üreticisi çalışır ve test kabloya gerçekten ne gittiğini
görür. Repository'yi mock'lamak bunu yakalayamaz — mock yanlış RPC adını da
mutlulukla kabul eder.

```dart
final wire = SupabaseWireHarness();
wire.respond('rpc_adi', {'kolon': 1});
final repo = SupabaseFooRepository(wire.client());

await repo.birSey();

expect(wire.rpc('rpc_adi').json, {'p_x': 1});   // kabloya giden parametreler
```

Hata yolu için `wire.failWith('rpc_adi', status: 404, message: '…')`.
En az bu üçünü kapsayın: **doğru RPC adı**, **yanıt ayrıştırma**, **sunucu
hatasının doğru istisnaya çevrilmesi**.

---

## 5. Yerelde tam tur

Tek komut — kapıları ucuzdan pahalıya sıralar, aynı kademedekileri paralel
koşturur ve tek bir sonuç tablosu basar:

```bash
python scripts/test_all.py
```

```bash
python scripts/test_all.py --fast
```

```bash
python scripts/test_all.py --full
```

`--fast` yalnız saniyelik kapılar + `flutter analyze`; varsayılan tur buna tam
Flutter paketi, Android native JVM testleri ve kapsam ratchet'ini ekler; `--full` golden, Windows entegrasyon ve
pgTAP yerel replay'i de koşturur. Tek kapı için `--only <anahtar>`, liste için
`--list`.

**Çıkış kodu sözleşmesi:** `0` = her kapı koştu ve geçti · `1` = kırmızı var ·
`3` = kırmızı yok ama en az bir kapı **koşmadı** (Deno kurulu değil, Docker
kalkmıyor…). Üçüncü kodun ayrı olması bilinçlidir: bu repoda "yeşil sanılan ama
hiç koşmayan kapı" üç kez pahalıya mal oldu (§0), o yüzden *ölçülmedi* ile
*geçti* aynı sayıya yazılmaz.

Kapıları koşturan ve kırmızıyı kök nedene kadar kovalayan rol:
`.agents/skills/tester/SKILL.md` ("tester'ı oku ve teste başla").

Alt komutlar hâlâ tek tek çalıştırılabilir:

```bash
cd app && flutter test --exclude-tags=golden --coverage --dart-define-from-file=env.json
```

```bash
python scripts/coverage_audit.py --top 30
```
