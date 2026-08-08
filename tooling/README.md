# Güvenli veritabanı ve release otomasyonu

Bu dizin WP-228'in local → staging → production kapılarını içerir. Komutlar
`supabase/.temp/project-ref` içindeki eski linke güvenmez; seçilen ortam, URL,
project-ref, tam git SHA ve migration head birbiriyle uyuşmadan remote komut
başlamaz.

## Tek komut local kanıt

```powershell
pnpm install --frozen-lockfile
pnpm db:baseline
```

Bu akış local Docker stack'i başlatır, boş DB'ye bütün migration zincirini
uygular ve gerçek pgTAP/RLS/invariant testlerini çalıştırır. Makine-okunur
manifest ve temizlenmiş loglar `.artifacts/deploy-evidence/` altında üretilir;
bu dizin git tarafından yok sayılır.

Guard testleri ayrıca hızlı çalıştırılabilir:

```powershell
pnpm deploy:guard:test
```

## Fresh staging önkoşulu (`pg_cron`)

Hosted staging projesi fresh olduğunda `cron` şeması bulunup `pg_cron` extension'ı
henüz kurulu olmayabilir. Tarihsel ve remote'a uygulanmış `0053` değiştirilmez.
Önce salt-okunur durum/migration geçmişi alınır; sonra yalnız izole staging ref'ine
kilitli sabit allowlist sorgusu `create extension if not exists pg_cron;` çalışır.
Wrapper serbest SQL kabul etmez ve production ref'ini reddeder. Aşağıdaki
`<4-digit-head>` yer tutucusuna `tooling/release/deploy-contract.json`
içindeki güncel head yazılır:

```powershell
./tooling/supabase/staging-prerequisites-owner.ps1 `
  -Action inspect `
  -ExpectedGitSha '<40-char-sha>' `
  -ExpectedMigrationHead '<4-digit-head>'

./tooling/supabase/staging-prerequisites-owner.ps1 `
  -Action bootstrap `
  -ExpectedGitSha '<40-char-sha>' `
  -ExpectedMigrationHead '<4-digit-head>'
```

Parola `Read-Host -AsSecureString` ile yalnız görünür terminal oturumunda alınır.
Inspect/bootstrap için explicit staging link, migration listesi ve öncesi/sonrası
durum sorguları temizlenmiş evidence manifestine kaydedilir.

## Deploy contract

`tooling/release/deploy-contract.json` tek public kapıdır ve local/staging/production
migration head'lerinin, `deploy_enabled` / `release_enabled` bayraklarının ve HOLD
gerekçelerinin **tek kanonik kaynağıdır**. Bu README bilerek hiçbir head numarası
veya kapı durumu tekrarlamaz — tekrarlanan her değer bayatlıyor (bu bölüm uzun süre
`0070` yazdı). Güncel değer için doğrudan contract dosyası okunur.

Kalıcı kurallar:

- Bir apply/release turu bittiğinde ilgili bayrak **ayrı bir commit'te** yeniden
  `false`'a kilitlenir; açık kalan kapı kazara production apply'ına izin verir
  (bu hata WP-255 ve WP-293'te iki kez yaşandı).
- Head numarası dört ayrı yerde pinlidir; contract güncellenirken `guard.tests.ps1`
  iddiaları da aynı commit'te güncellenir, yoksa guard kırmızı olur.
- Production CLI migration history uzlaştırılmamış olarak kalır
  (`docs/recovery/PRODUCTION-BASELINE.md` §3 — `supabase_migrations.schema_migrations`
  production'da yok); bu tarihsel bir kayıttır, bugünkü head için contract'a bakılır.
- WP-229 eşit-kaynak/ödül zinciri onarımı **tamamlandı**; eski `0063`/`0064` HOLD
  anlatımı kalktı, güncel durum contract dosyasındadır.

## GitHub kurulumu (owner)

Repository'de iki Environment oluştur:

1. `staging`
2. `production` — required reviewer ve deployment protection rule zorunlu;
   mümkünse self-review kapalı tutulur.

Repository variables (iki environment tarafından okunur):

- `STAGING_SUPABASE_PROJECT_REF`
- `PRODUCTION_SUPABASE_PROJECT_REF`

`staging` Environment secrets:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_DB_PASSWORD`
- `STAGING_SUPABASE_URL`
- `STAGING_SUPABASE_ANON_KEY`

`production` Environment secrets:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_DB_PASSWORD`
- `PRODUCTION_SUPABASE_URL`
- `PRODUCTION_SUPABASE_ANON_KEY`

Parola, access token, service role veya gerçek `env.json` sohbete, workflow
inputuna, repoya ya da kanıt manifestine yazılmaz. Production ve staging DB
parolaları farklı olmalıdır.

## Database Gates kullanımı

Pull request ve `main` değişikliklerinde yalnız local replay/test çalışır; fork
ve PR job'ları remote secret alamaz. Remote işlem yalnız GitHub Actions
`Database Gates` → `Run workflow` ile başlar.

Gerekli inputlar:

- operation: `staging-dry-run`, `staging-apply`, `production-dry-run` veya
  `production-apply`;
- exact 40 karakter commit SHA;
- `deploy-contract.json` içindeki dört haneli migration head.

`staging-apply` sırası: exact link → migration list → dry-run → push → migration
list → Docker CLI/engine readiness → linked pgTAP post-check → aynı commit/head
ile beta build ve SHA-256 raporu. Docker Desktop kurulu fakat CLI sistem PATH'inde
değilse wrapper standart Docker Desktop kurulum yolunu güvenli biçimde çözer.

WP-229 küçük reconciliation kabulü iki ayrı owner adımıdır. Her ikisi de exact
commit/head, explicit staging link ve migration-list öncesi/sonrası kanıtı üretir;
production ref'i ve allowlist dışı SQL fail-closed reddedilir:

```powershell
./tooling/supabase/staging-reconciliation-owner.ps1 -Action prepare -ExpectedGitSha '<40-char-sha>'
./tooling/supabase/staging-reconciliation-owner.ps1 -Action apply -ExpectedGitSha '<40-char-sha>'
```

Prepare sabit en fazla 10 kullanıcıyı aggregate olarak raporlar. Apply yalnız tek
bir `prepared` run varken çalışır ve session/duration/ledger/reward kayıp deltalarını
raporlar. Parola iki adımda da görünür terminalde `SecureString` olarak alınır;
run/kullanıcı kimlikleri ve gizli değerler evidence loglarına yazılmaz.

Gerçek staging beta APK'sı owner CLI oturumundaki publishable/anon anahtarı ekrana
ve loga yazılmadan seçilerek üretilir:

```powershell
./tooling/release/staging-beta-owner.ps1 -ExpectedGitSha '<40-char-sha>'
```

`beta-build.ps1` staging define manifestini sistem geçici dizininde oluşturur ve
her sonuçta siler. Mevcut `app/env.json` okunmaz, taşınmaz veya overwrite edilmez;
öncesi/sonrası SHA-256 eşitliği manifestte `local_env_preserved=true` olarak
kanıtlanır. Artefakt manifesti APK SHA-256'sını kaydeder. (Tarihsel örnek: WP-230
turunda beklenen kimlik `1.0.42-beta.1+4201`, backend staging, head `0064` idi;
bugünkü beklenen sürüm `app/pubspec.yaml`, beklenen head `deploy-contract.json`.)

`production-apply` bunlara ek olarak protected `production` Environment onayı,
`tooling/release/production-backup-checklist.example.json` sözleşmesine uyan
makine-okunur backup checklist JSON'u ve şu exact confirmation'ı ister:

```text
PRODUCTION GO:<40-char-sha>:<4-digit-head>:<production-project-ref>
```

Bu metin, staging/cihaz/soak/backup kanıtları hazır olduktan sonra yalnız o somut
deploy için kullanılır. Genel yetki yerine geçmez. `db reset --linked`, remote
`migration repair`, truncate/drop/delete komutları wrapper denylist'indedir.

## Local terminalden staging dry-run

Önce `supabase login` ile local CLI profile'ını kullan veya access token'ı güvenli
process environment'a koy. DB parolasını repoya yazmadan yalnız o terminal
oturumuna tanımla. Ardından:

```powershell
$securePassword = Read-Host 'Staging DB password' -AsSecureString
$passwordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
  $env:SUPABASE_DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
}
./tooling/supabase/remote.ps1 `
  -Environment staging `
  -Action dry-run `
  -ProjectRef '<staging-ref>' `
  -SupabaseUrl 'https://<staging-ref>.supabase.co' `
  -StagingProjectRef '<staging-ref>' `
  -ProductionProjectRef '<production-ref>' `
  -ExpectedGitSha '<40-char-sha>' `
  -ExpectedMigrationHead '<head>'
Remove-Item Env:SUPABASE_DB_PASSWORD
```

`deploy-contract.json` ilgili ortam için kapıyı kapalı tutuyorsa komut remote'a
ulaşmadan reddedilir; kapı açıkken aynı komut güvenli dry-run yapar. Stale link
hatasında
yalnız local link bilgisini kaldırmak için `supabase unlink` kullanılır; remote
reset yapılmaz.
