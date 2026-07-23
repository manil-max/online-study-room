# Staging Push Kabul Devri — 2026-07-23

## Hazır durum

- Staging migration head: `0070`.
- `pg_net 0.20.4` ve `net.http_post` mevcut.
- Runtime config health: `configured`.
- Son ölçümde ardışık beş cron koşusu `succeeded`.
- Queue: queued=0, retry=0, processing=0, stuck lease=0.
- Production/stable değişmedi ve HOLD durumundadır.

Kanıt:

- Database apply + post-check: GitHub Actions run `30017585795`.
- İlk onarım sonrası tanı: run `30017833357`.
- Ardışık cron ve boş kuyruk tanısı: run `30018384155`.
- Yerel replay: `.artifacts/deploy-evidence/20260723T144351722Z-local-baseline/`.

## Kalan tek yayın adımı

`beta-v4304` ve `beta-v4305` tag'leri önceki başarısız denemelerde kullanıldı;
yeniden kullanılmaz. Yeni aday:

- tag: `beta-v4306`
- version: `1.0.43-beta.6+4306`
- migration head: `0070`
- commit: yayın anındaki exact `main` HEAD

Normal Release Orchestrator tag tetikleyicisi kullanılmalıdır. Workflow, Android
ve Windows zorunlu artefaktları tamamlanmadan prerelease'i finalize etmez.

## Fiziksel cihaz kabulü

Yeni prerelease kurulduktan sonra
[`docs/qa/DEVICE-QA-MATRIX.md`](../qa/DEVICE-QA-MATRIX.md) bölüm E doldurulur:
foreground, background, process-terminated, zorlanmış retry, sayaç aksiyonları ve
20 ölçümlü remote self-test.

Bu cihaz kanıtı beta kabulüdür; production migration, stable tag veya Store
yayını için izin değildir.
