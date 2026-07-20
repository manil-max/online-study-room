# WP-227 — Beta/Stable Ortam İzolasyonu

> Tarih: 2026-07-20 (Europe/Istanbul)
> Durum: Kod + otomatik Android kanıtı hazır; staging proje oluşturma ve remote
> migration/seed owner kapısında bekliyor.
> Production: **salt-okunur/freeze; bu WP production'a yazmadı.**

## 1. Sonuç

Beta ve stable artık yalnız farklı tag değildir. Artefakt kimliği aşağıdaki beş
alan birlikte doğrulanmadan uygulama veri servislerini başlatmaz:

1. `CHANNEL` (`local` / `beta` / `stable`)
2. `APP_ENVIRONMENT` (`local` / `staging` / `production`)
3. Seçili `SUPABASE_PROJECT_REF` ve Supabase URL hostu
4. `GIT_COMMIT_SHA`
5. `MIGRATION_HEAD`

Android APK/AAB derlemesinde Gradle kapısı; Windows release akışında pre-build
Flutter test kapısı; bütün platformlarda uygulama başlangıcında Dart kapısı aynı
eşleşmeyi fail-closed doğrular. Release kanalında eksik anahtar artık sessizce
InMemory repository'ye düşmez. InMemory yalnız `local + ALLOW_IN_MEMORY=true`
ile açılabilir.

## 2. Kanonik ortam matrisi

| Kullanım | Flavor/kanal | Backend | Android application id | Ad | Auth callback |
|---|---|---|---|---|---|
| Yerel geliştirme | `local` | local Docker veya açık InMemory | `com.manilmax.online_study_room.local` | Odak Kampı LOCAL | `com.manilmax.onlinestudyroom.local://login-callback` |
| Beta APK | `beta` | ayrı staging Supabase | `com.manilmax.online_study_room.beta` | Odak Kampı BETA TEST | `com.manilmax.onlinestudyroom.beta://login-callback` |
| GitHub stable APK | `stable` | production Supabase | `com.manilmax.online_study_room` | Odak Kampı | `com.manilmax.onlinestudyroom://login-callback` |
| Play AAB | `play` + `stable` | production Supabase | `com.manilmax.online_study_room` | Odak Kampı | `com.manilmax.onlinestudyroom://login-callback` |
| Windows beta | `CHANNEL=beta` | staging Supabase | Windows package kimliği | Odak Kampı | Platform auth callback sözleşmesi ayrıca release QA'da doğrulanır |
| Windows stable | `CHANNEL=stable` | production Supabase | Windows package kimliği | Odak Kampı | Platform auth callback sözleşmesi ayrıca release QA'da doğrulanır |

Android SharedPreferences, uygulama cache'i, widget durumu ve plugin provider
authority'leri application id altında ayrılır. Merged-manifest kanıtında beta
provider authority'leri `.beta` taşırken stable taşımadı. Beta/stable launcher
ikonlarının SHA-256 değerleri de farklıdır. Böylece aynı telefonda yan yana
kurulumda auth/cache/widget alanı ortak değildir.

## 3. Fail-closed kuralları

| İstek | Sonuç |
|---|---|
| beta + staging URL/ref | Kabul |
| stable/play + production URL/ref | Kabul |
| beta + production environment veya ref | Build/startup reddi |
| stable/play + staging environment veya ref | Build/startup reddi |
| staging ref = production ref | Red |
| URL hostu seçili project-ref ile aynı değil | Red |
| release Supabase URL/key eksik | Red; InMemory fallback yok |
| `sb_secret_*` / service-role client key | Red |
| commit SHA veya dört haneli migration head eksik | Red |

Hata yüzeyi URL, key veya token göstermez; yalnız secret içermeyen tanı kodu
gösterir. Ayarlar → Sürüm ve güncellemeler ekranının üstündeki **Derleme tanısı**
kartı kanal, backend aliası, kısaltılmış commit ve migration head'i gösterir.

## 4. Env dosyaları

Repoda yalnız şablon bulunur:

- `app/env.local.example.json`
- `app/env.staging.example.json`
- `app/env.production.example.json`

Gerçek dosya daima `app/env.json` olur ve git tarafından yok sayılır. Ayrıca
`env.*.json` gerçek varyantları ignore edilir; yalnız `*.example.json` commit
edilebilir. Release şablonlarındaki `REPLACE_*`/sentetik ref alanları bilerek
build geçemez.

Yerel InMemory çalıştırma:

```powershell
cd app
Copy-Item env.local.example.json env.json
flutter run --flavor local --dart-define-from-file=env.json
```

Local Supabase kullanılacaksa `ALLOW_IN_MEMORY=false`, URL
`http://127.0.0.1:54321`, project ref `local` ve `supabase status` çıktısındaki
anon/publishable key yerel `env.json` içine yazılır.

## 5. GitHub secret/variable sözleşmesi

İki backend aynı secret adını paylaşmaz. Repository/Environment ayarlarında:

**Secrets**

- `STAGING_SUPABASE_URL`
- `STAGING_SUPABASE_ANON_KEY`
- `PRODUCTION_SUPABASE_URL`
- `PRODUCTION_SUPABASE_ANON_KEY`

**Variables (public kimlik; yine de workflow üzerinden yönetilir)**

- `STAGING_SUPABASE_PROJECT_REF`
- `PRODUCTION_SUPABASE_PROJECT_REF`

Beta workflow yalnız `STAGING_*`; stable/play yalnız `PRODUCTION_*` credential
seçer. Her iki project-ref de manifestte bulunur ve birbirine eşit olamaz.
`service_role`, DB parolası ve access token hiçbir app build secret'ı değildir.

## 6. Staging projesi owner checklist

CLI oturumu 2026-07-20'de doğrulandı: aynı Supabase hesabında bir aktif production
projesi var; ayrı staging projesi henüz yok. Proje oluşturma DB parolasını CLI
argümanı olarak ister. Parolayı ajana/sohbete/loga vermeden owner'ın kendi
terminalinde veya Supabase Dashboard'da oluşturması zorunludur.

1. Supabase Dashboard'da plan/kota ve olası maliyet etkisini kontrol et. Ayrı
   proje ayrı DB/Auth/Storage kaynakları tüketir; kesin limit hesabın planına
   bağlıdır.
2. Aynı organization altında `online-study-room-staging` oluştur.
3. Production parity için bölgeyi `ap-northeast-1` seç; DB parolasını parola
   yöneticisinde sakla. Production parolasını yeniden kullanma.
4. Project ref ve publishable/anon key'i yalnız yerel `app/env.json` ile GitHub
   `STAGING_*` secret/variable alanlarına yaz. Sohbete veya git'e koyma.
5. Staging Auth → URL Configuration'a
   `com.manilmax.onlinestudyroom.beta://login-callback` ekle. Production'da yalnız
   stable callback'i koru.
6. Test kullanıcılarını staging Auth içinde yeniden oluştur. Production Auth
   kullanıcıları/verisi staging'e kopyalanmaz.
7. Bu aşamada `supabase link`, `db push`, remote seed veya `migration repair`
   çalıştırma; aşağıdaki migration HOLD kapısını uygula.

CLI ile proje oluşturmak tercih edilirse organization id önce salt-okunur
`supabase orgs list` ile alınır; parola `Read-Host -AsSecureString` ile owner
terminalinde girilir. Parola hiçbir komut çıktısında paylaşılmaz. Tek seferlik
project create sonrasında proje referansı kaydedilir ve CLI hedefi her remote
komuttan önce açıkça yeniden doğrulanır.

## 7. Migration/seed HOLD — neden staging'e henüz push yok

Kabul edilmeyen `0063_equal_study_sources.sql` hiçbir remote'a uygulanmadı ve
WP-229'da güvenli ileri tasarım bekliyor. Bugün `supabase db push` çalıştırmak
0063'ü staging'e uygulayıp immutable hale getirir; bu hem kullanıcının
“kurtarma migration'larını sonraya ertele” kararına hem recovery sırasına aykırı.

Bu nedenle WP-227 şu remote işlemleri **bilinçli olarak yapmadı**:

- staging `db push`
- staging seed/DML
- production link/push/repair/backfill
- production verisini staging'e kopyalama

Remote kurulum WP-228 güvenli hedef doğrulaması hazır olduktan ve WP-229 kabul
edilmiş kanonik head'i ürettikten sonra şu sırayla yapılır: local replay+test →
staging migration list → staging dry-run → açık staging target → push → yalnız
sentetik seed → RLS/invariant post-check.

Remote manifest head geçici olarak `0062`, local replay head `0063` olarak
belgelenir. Bu değer WP-229 kabul commit'iyle ileri alınmadan beta release yoktur.

## 8. Otomatik kanıt

2026-07-20 yerel kanıtları:

- `flutter analyze`: 0 issue
- WP-227 hedef testleri: 34/34 PASS
- tüm Flutter regresyon paketi: 631/631 PASS
- Gradle Kotlin DSL/config: PASS; `local/beta/stable/play` variant'ları üretildi
- `local` debug APK: PASS
- sentetik doğru kimlikle beta debug APK: PASS
- sentetik doğru kimlikle stable debug APK: PASS
- Windows beta manifest preflight + debug build: PASS
- beta + production manifest: build exit 1 / REJECTED
- stable + staging manifest: build exit 1 / REJECTED
- APK kimliği:
  - local: `.local` + local callback
  - beta: `.beta` + beta callback
  - stable: production package + stable callback

Sentetik hosted URL/key ile üretilen debug APK'lar yalnız build-contract
kanıtıdır; gerçek staging bağlantısı veya cihaz QA kanıtı değildir.

## 9. Cihaz QA / kabul

Staging proje hazır olduktan sonra gerçek Android cihazda:

1. stable ve beta yan yana kurulur; iki farklı launcher adı/ikonu görünür.
2. Beta hesabı staging'de açılır; stable login durumu beta içinde görünmez.
3. Her ikisinde ayrı widget eklenir; sayaç/cache/auth durumu çapraz taşınmaz.
4. Beta auth recovery yalnız beta callback'i; stable yalnız stable callback'i açar.
5. Ayarlar → Sürüm ve güncellemeler tanı kartında beta=`staging`,
   stable=`production` görünür.
6. Beta updater yalnız beta release; stable updater beta prerelease görmez.

Bu matris cihazda ve gerçek staging'de geçmeden WP-227 ürün kabulü almaz.

## 10. Geri alma

Bu WP remote şema/veri değiştirmediği için veri rollback'i yoktur. Kod rollback'i
tek WP commit'inin revert edilmesidir. Release keystore değiştirilmedi; stable
application id ve Play identity korunur. Revert halinde eski ortak-backend riski
geri geleceğinden beta release yine freeze altında kalır.
