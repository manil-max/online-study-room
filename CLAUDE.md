# CLAUDE.md

> Bu proje **İş Paketi (WP) + Kalite Programı** ile yürür. Kurallar tüm ajanlar için ortaktır.

**Başlarken `AGENTS.md`'yi (repo kökü) oku** — giriş noktası ve işaretçi orasıdır. Tam kurallar `.agents/AGENTS.md`, roller `.agents/skills/{planner,worker}/SKILL.md`, kanonik program `docs/KALITE-PROGRAMI.md`.

## Tetik
- `worker'ı oku, WP-N'yi yap` → `.agents/skills/worker/SKILL.md` + `progress.md`'de WP-N.
- `planner'ı oku, şunu planla` → `.agents/skills/planner/SKILL.md`.

## Kod yazmadan önce (zorunlu)
1. `progress.md` **Aktif Çalışma Kaydı**'nı oku; başka aktif ajanla **çakışma** varsa BAŞLAMA, kullanıcıyı uyar (iş sana verilmiş olsa bile).
2. Claim et + **WP başına ayrı dal** aç (`wpNN-kisa-ad`).

## Vazgeçilmezler
- `flutter` `app/` içinde; `run/test/build`'e `--dart-define-from-file=env.json`; `analyze` bayrak almaz.
- Gizli dosya commit etme; **RLS zorunlu**; XP/kritik ilerleme **server-authoritative**; repository çift (`supabase/`+`in_memory/`).
- Kullanıcı metni Türkçe; gün sınırı Europe/Istanbul.
- Push/merge yok (istenmedikçe); merge otomasyonu = **A** (kurulum WP-39).
- "Tamamlandı" = cihazda güvenilir + kullanıcı beklentisini karşılayan iş (DoD: `.agents/AGENTS.md §3`).

Kullanıcının el kitabı: `docs/AJAN-KULLANIM.md`.
