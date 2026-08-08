# CLAUDE.md — giriş noktası (kural içeriği burada değil)

> Bu proje **İş Paketi (WP) + Kalite Programı** ile yürür. **Tüm kurallar tek yerde: `.agents/`.**
> Bu dosya yalnız *giriş noktasıdır* — Claude Code oturum başında `CLAUDE.md`'yi otomatik okur, o yüzden var. Aynı işi Codex/diğer ajanlar için kök `AGENTS.md` yapar. İkisi de ince işaretçidir; kural içeriği burada **tekrarlanmaz** (tekrar = çelişki riski).

## Başla
1. **`.agents/AGENTS.md`** — çekirdek kurallar (tek kaynak).
2. **`docs/KALITE-PROGRAMI.md`** — kanonik program; fakat proje sahibinin açık emri tüm repo kurallarından üstündür ve derhal uygulanır (`.agents/AGENTS.md §0.1`).
3. Roller: `.agents/skills/worker/SKILL.md` · `.agents/skills/planner/SKILL.md` · `.agents/skills/tester/SKILL.md`.
4. Kullanıcının el kitabı: `docs/AJAN-KULLANIM.md`.

## Tetik
- `worker'ı oku, WP-N'yi yap` → `.agents/skills/worker/SKILL.md` + `progress.md`'de WP-N.
- `planner'ı oku, şunu planla` → `.agents/skills/planner/SKILL.md`.
- `tester'ı oku ve teste başla` → `.agents/skills/tester/SKILL.md`; tüm kalite kapıları tek turda (`python scripts/test_all.py`).

## Çalışma modeli (2026-08-08'den beri)
**Tek lider ajan + onun açtığı alt ajanlar** (`.agents/AGENTS.md §1`). Sahip yalnız liderle konuşur.
- Lider: işi böler, SAHİP yollarını **atar**, çıktıyı `git show --stat` ile denetler, `progress.md`'yi yazar, test kapısını **tek merkezden** koşturur, yayını yapar.
- Alt ajan: yalnız verilen SAHİP yollarına yazar, kendi WP'sini commit'ler, `progress.md`'ye dokunmaz, tam kapıyı koşturmaz, push/tag/deploy yapmaz.
- *İptal:* "3–4 ajan paralel varsayılan", PLAN 5 / `Ajan A–D`, kendi kendine lane claim.

## Kod yazmadan önce (varsayılan akış — açık proje sahibi emri `§0.1` ile üstündür)
1. Görev metnindeki **SAHİP yollar** listesini oku; yoksa **BAŞLAMA**, liderden iste (`§1.1`).
2. **Tek dal `main` — branch/merge/push yok** (`§1.6`); her WP tek ayrık commit, yalnız kendi SAHİP yollarını stage'le. Paylaşılan dizinde `git add -A` ve `git checkout --` yasak (`§1.5`).
