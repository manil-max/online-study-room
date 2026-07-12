# AGENTS.md — Başla buradan (işaretçi)

> Bu, her ajanın ilk okuduğu giriş noktasıdır. **Tam kurallar `.agents/AGENTS.md`'de.**

## Tetik
- **İş yapma:** Kullanıcı "worker'ı oku, WP-N'yi yap" → önce `.agents/skills/worker/SKILL.md` oku, sonra `progress.md`'de WP-N kartını bul.
- **Planlama:** Kullanıcı "planner'ı oku, şunu planla" → `.agents/skills/planner/SKILL.md` oku.

## Başlamadan önce (ZORUNLU — atlanmaz)
1. **`.agents/AGENTS.md`'yi oku** (çekirdek kurallar) ve **`docs/KALITE-PROGRAMI.md`** (kanonik program).
2. **Çakışma ön-kontrolü:** `progress.md`'deki **Aktif Çalışma Kaydı**'nı oku. Verilen işin SAHİP dosyaları başka aktif ajanla kesişiyorsa **BAŞLAMA — kullanıcıyı gerekçeyle uyar** (kullanıcı işi açıkça vermiş olsa bile). Bkz. `.agents/AGENTS.md §1`.
3. **Claim et:** kod yazmadan önce kendi lane'ini Aktif Çalışma Kaydı'na işle; **WP başına ayrı dal** aç (`wpNN-kisa-ad`).

## Vazgeçilmezler
- `flutter` komutları **`app/` içinde**; `run/test/build`'e **`--dart-define-from-file=env.json`** geç (`analyze` bayrağı almaz).
- **Gizli dosya commit etme** (`env.json`, `key.jks`, `key.properties`, `service_role`). **RLS zorunlu**, XP/kritik ilerleme **server-authoritative**.
- Repository **çift** (`supabase/` + `in_memory/`). Kullanıcı metni **Türkçe**, gün sınırı **Europe/Istanbul**.
- **Push/merge yok** (kullanıcı istemedikçe). Merge otomasyonu = **A** (PR + CI auto-merge, kurulum WP-39).
- "Tamamlandı" = kod değil; **cihazda güvenilir + kullanıcı beklentisini karşılayan** iş. DoD için `.agents/AGENTS.md §3`.

## Haritalama
| Dosya | Ne |
|---|---|
| `.agents/AGENTS.md` | Tam kurallar |
| `.agents/skills/worker/SKILL.md` | Uygulayıcı akışı |
| `.agents/skills/planner/SKILL.md` | Planlayıcı akışı |
| `progress.md` | Aktif Çalışma Kaydı + WP'ler |
| `docs/KALITE-PROGRAMI.md` | Kanonik program/plan |
| `docs/AJAN-KULLANIM.md` | Kullanıcının el kitabı |
| `project.md` · `backlog.md` | Teknik referans · backlog |
