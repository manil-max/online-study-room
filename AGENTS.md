# AGENTS.md — giriş noktası (kural içeriği `.agents/`'te)

> Her ajanın ilk okuduğu dosya. **Tam kurallar: [`.agents/AGENTS.md`](.agents/AGENTS.md).** Çelişkide `docs/KALITE-PROGRAMI.md` kazanır.
> Bu dosya bilinçli olarak incedir: Codex ve diğer araçlar kökteki `AGENTS.md`'yi, Claude Code `CLAUDE.md`'yi otomatik okur — ikisi de aynı yere (`​.agents/`) yönlendiren işaretçidir. Kural burada **tekrarlanmaz** (tekrar geçmişte dal/WP-39 çelişkisi doğurdu).

## Tetik
- **İş yapma:** "worker'ı oku, WP-N'yi yap" → `.agents/skills/worker/SKILL.md`, sonra `progress.md`'de WP-N kartı.
- **Planlama:** "planner'ı oku, şunu planla" → `.agents/skills/planner/SKILL.md`.

## Başlamadan önce (ZORUNLU — atlanmaz; tam kural `.agents/AGENTS.md §1`)
1. **`.agents/AGENTS.md` + `docs/KALITE-PROGRAMI.md`** oku.
2. **Çakışma ön-kontrolü:** `progress.md` **Aktif Çalışma Kaydı**'nı oku. Verilen işin SAHİP dosyaları başka aktif ajanla kesişiyorsa **BAŞLAMA — kullanıcıyı gerekçeyle uyar** (iş sana açıkça verilmiş olsa bile).
3. **Claim:** kod yazmadan önce kendi lane'ini Aktif Çalışma Kaydı'na işle.

## Vazgeçilmezler (özet — tam liste ve öncelik `.agents/AGENTS.md`)
- `flutter` **`app/` içinde**; `run/test/build`'e **`--dart-define-from-file=env.json`** (yoksa sessizce InMemory'ye düşer); `analyze` bu bayrağı **almaz**.
- **Gizli dosya commit etme** (`env.json`, `key.jks`, `key.properties`, `service_role`). **RLS zorunlu**; XP/kritik ilerleme **server-authoritative**; repository **çift** (`supabase/` + `in_memory/`).
- Kullanıcı metni **Türkçe**; gün sınırı **Europe/Istanbul**.
- **Tek dal `main` — branch/merge/push yok** (kullanıcı istemedikçe); her WP tek ayrık commit, `git add -A` yasak; çakışma dallarla değil **Aktif Çalışma Kaydı + ayrık SAHİP dosyalar** ile önlenir (`§1.5`). *(Eski "CI auto-merge / WP-39" planı iptal edildi.)*
- "Tamamlandı" = kod değil; **cihazda güvenilir + kullanıcı beklentisini karşılayan** iş (DoD: `.agents/AGENTS.md §3`).

## Haritalama
| Dosya | Ne |
|---|---|
| `.agents/AGENTS.md` | **Tam kurallar (tek kaynak)** |
| `.agents/skills/worker/SKILL.md` | Uygulayıcı akışı |
| `.agents/skills/planner/SKILL.md` | Planlayıcı akışı |
| `progress.md` | Aktif Çalışma Kaydı + aktif WP'ler |
| `docs/KALITE-PROGRAMI.md` | Kanonik program/plan |
| `docs/AJAN-KULLANIM.md` | Kullanıcının el kitabı |
| `backlog.md` · `project.md` | Backlog · teknik referans |
| `CLAUDE.md` | Claude Code için ikiz giriş noktası (bu dosyaya yönlendirir) |
