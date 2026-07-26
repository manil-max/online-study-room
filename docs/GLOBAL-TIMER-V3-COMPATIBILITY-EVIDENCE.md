# WP-337 — V3 legacy compatibility ve donuk kontrat kanıtı

> Tarih: 2026-07-26 · Hedef: Delivery C0 · Karar: **NO-GO**
>
> Kapsam yalnız salt-okunur envanter ve kontrat testidir. Migration, feature,
> deploy veya remote veri mutasyonu yapılmadı.

## Hüküm

WP-341 migration'ı **yazılmamalı**. Yerel kaynak/plan kontratları G1–G6 ve
H1–H4 kararlarını kapatıyor; ancak zorunlu `running`/`paused` satır sayısı
local, staging ve production için bu turda güvenilir biçimde ölçülemedi.
Özellikle staging için hiç güncel aggregate kanıtı yoktur. Production'da
2026-07-20 salt-okunur baseline, 0051 çekirdeğinin varlığını doğruladı fakat
açık legacy run sayılarını rapora kaydetmedi; eski bir schema hash'i güncel
satır sayısı yerine geçmez.

Yeni migration ancak her ortamda, hedef kimliği doğrulanmış salt-okunur
transaction içinde aşağıdaki aggregate kaydedildikten sonra GO alabilir:

```sql
select status, count(*)
from public.live_study_runs
where status in ('running', 'paused')
group by status;
```

Sorgu yalnız aggregate döndürür; UUID, token, e-posta veya run payload'ı
kaydedilmez. Production sorgusu `BEGIN ... READ ONLY`/`ROLLBACK` ile ve
production freeze bozulmadan yürütülmelidir.

## Ortam kanıtı

| Ortam | Durum | Kanıt | Sonuç |
| --- | --- | --- | --- |
| Local | Ölçülemedi | `tooling/supabase/local.ps1 status` 2026-07-26'da local servislerin durduğunu gösterdi; reset başlatılmadı. | FAIL — güncel count yok |
| Staging | Ölçülemedi | Migration head `0072`; WP-337 için kabul edilmiş salt-okunur aggregate artefaktı bulunmadı. | FAIL — güncel count yok |
| Production | Kısmi/tarihsel | `docs/recovery/PRODUCTION-BASELINE.md` (2026-07-20) 0051 dosya hash'ini ve salt-okunur baseline'ı doğrular; açık run aggregate'ı rapora yazılmamış. | FAIL — güncel count yok |

Bu FAIL'ler bir veri arızası iddiası değildir; migration öncesi gereken bilginin
eksik olduğunu belirtir. Remote betik yalnız tanımlı korumalı operasyonları
çalıştırabildiğinden, bu WP kendi sahibinin dışında yeni remote sorgu yolu
eklemedi.

## G kapıları — legacy/V2 uyumluluk kararı

| Kapı | Sonuç | Kodda doğrulanan karar |
| --- | --- | --- |
| G1 | PASS | `live_study_runs_one_active_user`, `running/paused` üzerinde tek legacy active-run index'idir. WP-341 aynı transaction'da onu kaldırıp `run_kind='study'` ve `running/paused` için tek birleşik index kuracak; iki active unique index birlikte kalmayacak. |
| G2 | PASS | Otorite mevcut `status` alanıdır; ikinci `state` alanı eklenmez. Legacy CHECK bugün yalnız `running/paused/finalized/cancelled` kabul eder; WP-341 bunu `stopped/abandoned` ile ileri yönde genişletecek. V2 yalnız `running/stopped/abandoned` üretir. |
| G3 | PASS | `client_request_id NOT NULL` ve `unique(user_id, client_request_id)` korunur. V2 start `command_id` değerini aynen `client_request_id` olarak yazar; idempotency kullanıcı kapsamındadır. |
| G4 | PASS | V1/V2 stop server finalizer değildir: V2 `finalized` üretmez ve session/XP yazmaz. `finalized` ile `finalized_at + session_id` eşlemesi legacy/future-finalizer sözleşmesi olarak kalır. |
| G5 | PASS | `live_study_segments` append-only work-segment iskeletidir, Pomodoro ledger değildir. `pendingIntervals` hem interval hem legacy verified-command kayıtlarını taşıyan heterojen kuyruğa sahiptir; retroaktif rewrite yoktur. |
| G6 | PASS | `_verifiedServerAvailable` V2 kapısı değildir ve `false` kalır. V2 ancak ayrı, cohort/kill-switch destekli bir feature flag ile açılır; native background uplink, remote auto-start ve server finalizer bu WP'nin dışındadır. |

Legacy start RPC'si bugün kullanıcı başına `hashtextextended(user_id, 216)`
advisory transaction lock kullanır. V2 start RPC'si aynı lock alanını kullanmak
zorundadır; birleşik index son savunmadır, yarış çözümünün ilk mekanizması
değildir.

## H kapıları — plan tutarlılığı

| Kapı | Sonuç | Kanıt |
| --- | --- | --- |
| H1 | PASS | `global_timer_runs` yalnız kavramsal başlık olarak kalır; RFC fiziksel adayın mevcut `live_study_runs` olduğunu açıklar. |
| H2 | PASS | Kanonik gerçek için yeni paralel run tablosu varsayılmaz; mevcut tablo additive evrilir. |
| H3 | PASS | Checklist doğru testi `app/test/core/stats/wp231_stats_contract_test.dart` olarak gösterir. |
| H4 | PASS | Command idempotency matrisi, B'nin `command_id` değeriyle A auth'u geldiğinde A için bağımsız komut işlenmesini ve B `result_snapshot`'ının dönmemesini içerir. |

## Donuk istemci/native sınırları

- `LiveStudyRun` ve `LiveRunStatus` legacy DTO'su değişmeyecek; V2 snapshot
  ayrı DTO/RPC ile parse edilecek.
- `TimerExternalCommandStore.commandSeq` yalnız bildirim/widget eylemini Dart'a
  tek sefer taşır; distributed server command sırası değildir.
- `pendingIntervals` kalıcı, heterojen ve kısmi-ack'li kuyruğudur. V2 kaydı
  `kind`, `schema_version`, `command_id` ve `account_id` discriminator'larını
  taşıyacak; boş veya legacy biçimini taklit eden `runToken` üretmeyecek.
- `LiveStudyRun`, `study_providers.dart` ve Android native kaynakları bu WP'de
  değiştirilmedi.

## Otomatik kontrat

`app/test/data/global_timer_v3_legacy_contract_test.dart` şu fail-closed
sözleşmeyi doğrular:

1. Legacy active-run index, status CHECK, `client_request_id` unique/NOT NULL
   ve finalized eşlemesi.
2. Legacy RPC'nin kullanıcı advisory lock'ı; Supabase ve InMemory repository
   idempotency davranışı.
3. Donuk legacy DTO/parser ve kapalı legacy server flag.
4. `commandSeq` ile `pendingIntervals` ayrımı ve V2'nin tek-index/ayrı-flag
   kararları.

## Sonraki güvenli adım

WP-341 sahibine, önce ilgili korumalı remote operasyon yoluna yalnız bu aggregate
ve index/CHECK metadata'sını üreten redakte edilmiş salt-okunur kanıt ekleme
yetkisi verilmelidir. Üç ortam sonucu bu dosyaya kaydedilip **GO** olmadan
`008x_global_timer_v2.sql` oluşturulamaz.
