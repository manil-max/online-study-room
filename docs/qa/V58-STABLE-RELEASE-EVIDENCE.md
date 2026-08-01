# v58 Stable Release Kanıtı

> Tarih: 2026-08-01 (Europe/Istanbul)  
> Aday: `v58` · `1.0.58+58` · migration head `0119`  
> Durum: **HAZIRLIK — remote terfi ve release sonuçları aşağıya işlenecek.**

## Kapsam ve sahip kararı

Bu paket v57 sonrasındaki Faz F4 işlerini, WP-482 sayaç/widget ileri
düzeltmesini, Android native tester kapısını ve WP-486A duyuru güvenliğini tek
stable adayında toplar.

Proje sahibi 2026-08-01 tarihinde “her şeyi bitir, en son stable çıkaralım”
diyerek v58 staging → production → stable zincirine açık GO verdi. Fiziksel
iki-cihaz/OEM kabulünü stable güncelleme üzerinde kendisi yapacağını ayrıca
belirtti. Bu karar cihaz testini yayın-sonrası kabul/risk kapısı yapar; otomatik
testlerin fiziksel cihaz davranışını kanıtladığı anlamına gelmez.

Production Supabase free plan ortamında günlük backup/PITR yoktur. Deploy
contract'taki owner no-backup/no-rollback waiver kaydı geçerlidir. Migration
zinciri yalnız ileri düzeltmeyle kurtarılabilir; production apply protected CI,
exact SHA/head/project-ref confirmation ve staging post-check sonrasında yapılır.

## Yayın öncesi kanıt

| Kapı | Sonuç |
| --- | --- |
| Hedefli global timer Flutter regresyonu | 26/26 geçti |
| Android native JVM widget projeksiyonu | Geçti |
| WP-486A admin widget regresyonu | 2/2 geçti · 320 px ve 1.6× text scale dahil |
| Flutter analyze | 0 sorun |
| Yerel migration reset/replay | `0001→0119` · 48 dosya · 678 pgTAP geçti |
| L10n | 1499 EN/TR anahtar + 66 Android anahtar eşleşti |
| Kapsam ratchet | Genel %65.23 · kritik %58.92 |
| Deno Edge check/test | Yerelde Deno yok; aday SHA GitHub CI kanıtı zorunlu |

Kanonik aday SHA hazırlık commit'inden sonra `git rev-parse HEAD` ile alınır;
Database Gates ve Release Orchestrator girdilerinin tamamı aynı SHA'ya pinlenir.

## Terfi sırası

1. Aday commitini `main`e push et; CI ve Database Gates validate tamamen yeşil
   olsun.
2. Aynı SHA/head ile staging dry-run ve staging apply çalıştır; post-check
   `local|remote|file = 0119` doğrulasın.
3. Production dry-run ile yalnız `0117–0119` farkını doğrula.
4. Exact production confirmation ve kayıtlı waiver ile production apply yap;
   post-check `0119` olmadan release başlatma.
5. `v58` tag'ini exact aday SHA'da oluştur; protected Release Orchestrator ile
   production manifestli Android stable APK ve Windows artefaktlarını üret.
6. GitHub release'in draft/prerelease olmadığını, complete manifesti ve SHA-256
   dosyalarını doğrula; staging/production deploy bayraklarını yeniden kilitle.

## Tamamlanan zincir

- Exact release SHA: _bekliyor_
- CI / Database Gates validate: _bekliyor_
- Staging dry-run/apply: _bekliyor_
- Production dry-run/apply: _bekliyor_
- Stable Release Orchestrator: _bekliyor_
- Kapıları yeniden kilitleme: _bekliyor_

