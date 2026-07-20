# Supabase şema kaynağı

Bu klasör local, staging ve production için tek kanonik migration zinciridir.
Migration'lar artık SQL Editor'a tek tek yapıştırılmaz ve ortama göre
çatallanmaz.

## Ortam sırası

1. Local Docker: boş DB replay + pgTAP/RLS/invariant testleri.
2. Ayrı staging projesi: migration list + dry-run + push + post-check.
3. Beta cihaz QA ve en az üç günlük soak.
4. Backup + production dry-run + somut kullanıcı GO.
5. Aynı migration ve commit'in production'a terfisi + post-check.

Detaylı kurallar: `docs/ORTAM-MIGRATION-YONETISIMI.md`. Çalıştırılabilir komutlar
ve GitHub Environment kurulumu: `tooling/README.md`.

## Local kullanım

Repo kökünden:

```powershell
pnpm install --frozen-lockfile
pnpm db:baseline
```

Bu komut `supabase/config.toml`, `roles.sql`, bütün migration'lar, sentetik
`seed.sql` ve `supabase/tests/*.test.sql` ile sıfırdan kanıt üretir.

## Güvenlik

- `service_role`, access token, DB parolası ve gerçek `app/env.json` commit
  edilmez.
- Uygulanmış remote migration değiştirilmez; düzeltme yeni ileri migration'dır.
- `supabase db reset --linked` bütün remote ortamlarda yasaktır.
- Production `migration repair`, push, backfill veya veri düzeltmesi açık WP,
  backup, staging kanıtı ve o somut işlem için kullanıcı GO olmadan yapılmaz.
- Production verisi staging'e kopyalanmaz; staging sentetik test hesabı/fixture
  kullanır.

## Geçici kurtarma HOLD'u

`0063_equal_study_sources.sql` production'a ve staging'e uygulanmaz. WP-229
eşit-kaynak/ödül zinciri onarımını kabul edilmiş ileri migration olarak
tamamlayana kadar `tooling/release/deploy-contract.json` staging ve production
apply/release kapılarını kapalı tutar.
