# Data Safety envanter anlık görüntüsü (WP-119/132)

> Console formu **gönderilmedi**. Bu dosya kod envanteri özeti.

| Veri | Toplanır mı | Amaç | Paylaşım |
|---|---|---|---|
| E-posta / auth | Evet (Supabase Auth) | Hesap | Supabase |
| Display name / avatar | Evet | Profil / grup | Ortak grup üyeleri (RLS) |
| Study sessions | Evet | İstatistik / XP | Self; grup aggregate RPC |
| Subjects | Evet | Kişisel dersler | Self |
| Device notifications prefs | Yerel | Hatırlatma | Cihaz |
| Sentry | Opsiyonel crash | Stabilite | Sentry (DSN yapılandırılırsa) |
| Ads ID | Hayır | — | — |

Hesap silme: in-app istek + purge pipeline (Edge deploy **sahip**).

Detay: mevcut `docs/play-store/` ve DATA-SAFETY belgeleri.
