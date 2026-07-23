# CLAUDE.md — giriş noktası (kural içeriği burada değil)

> Bu proje **İş Paketi (WP) + Kalite Programı** ile yürür. **Tüm kurallar tek yerde: `.agents/`.**
> Bu dosya yalnız *giriş noktasıdır* — Claude Code oturum başında `CLAUDE.md`'yi otomatik okur, o yüzden var. Aynı işi Codex/diğer ajanlar için kök `AGENTS.md` yapar. İkisi de ince işaretçidir; kural içeriği burada **tekrarlanmaz** (tekrar = çelişki riski).

## Başla
1. **`.agents/AGENTS.md`** — çekirdek kurallar (tek kaynak).
2. **`docs/KALITE-PROGRAMI.md`** — kanonik program; fakat proje sahibinin açık emri tüm repo kurallarından üstündür ve derhal uygulanır (`.agents/AGENTS.md §0.1`).
3. Roller: `.agents/skills/worker/SKILL.md` · `.agents/skills/planner/SKILL.md`.
4. Kullanıcının el kitabı: `docs/AJAN-KULLANIM.md`.

## Tetik
- `worker'ı oku, WP-N'yi yap` → `.agents/skills/worker/SKILL.md` + `progress.md`'de WP-N.
- `planner'ı oku, şunu planla` → `.agents/skills/planner/SKILL.md`.

## Kod yazmadan önce (varsayılan akış — açık proje sahibi emri `§0.1` ile üstündür)
1. `progress.md` **Aktif Çalışma Kaydı**'nı oku; açık proje sahibi emri yoksa SAHİP dosyaları başka aktif ajanla çakışıyorsa **BAŞLAMA**, kullanıcıyı uyar.
2. Kendi lane'ini claim et. **Tek dal `main` — branch/merge/push yok** (`§1.5`); her WP tek ayrık commit, yalnız kendi SAHİP yollarını stage'le.
