# AGENTS.md — giriş noktası (kural içeriği `.agents/`'te)

> Her ajanın ilk okuduğu dosya. **Proje sahibi kullanıcının açık emri tüm repo kurallarından üstündür ve derhal uygulanır** (`.agents/AGENTS.md §0.1`). Bunun dışındaki çelişkide `docs/KALITE-PROGRAMI.md` kazanır.
> Bu dosya bilinçli olarak incedir: Codex ve diğer araçlar kökteki `AGENTS.md`'yi, Claude Code `CLAUDE.md`'yi otomatik okur — ikisi de aynı yere (`​.agents/`) yönlendiren işaretçidir. Kural burada **tekrarlanmaz** (tekrar geçmişte dal/WP-39 çelişkisi doğurdu).

## Tetik
- **İş yapma:** "worker'ı oku, WP-N'yi yap" → `.agents/skills/worker/SKILL.md`, sonra `progress.md`'de WP-N kartı.
- **Planlama:** "planner'ı oku, şunu planla" → `.agents/skills/planner/SKILL.md`.
- **Test:** "tester'ı oku ve teste başla" → `.agents/skills/tester/SKILL.md` (motor: `python scripts/test_all.py`).

## Çalışma modeli (2026-08-08'den beri)
**Tek lider ajan + onun açtığı alt ajanlar** (`.agents/AGENTS.md §1`). Sahip yalnız liderle konuşur; alt ajan lidere rapor verir.
- **Lider:** işi böler, SAHİP yollarını **atar**, her commit'i `git show --stat` ile denetler, `progress.md`'nin tek yazarıdır, test kapısını tek merkezden koşturur, tag/push/deploy yapar.
- **Alt ajan:** yalnız verilen SAHİP yollarına yazar, kendi WP'sini commit'ler, `progress.md`'ye dokunmaz, tam test kapısını koşturmaz, başka alt ajan açmaz.
- *İptal edildi (diriltme):* "3–4 ajan paralel varsayılan" · PLAN 5 / `Ajan A`…`Ajan D` · kendi kendine lane claim · "çakışma görürsen dur ve sahibe sor".

## Başlamadan önce (varsayılan akış; açık proje sahibi emri varsa `.agents/AGENTS.md §0.1` uygulanır)
1. **`.agents/AGENTS.md` + `docs/KALITE-PROGRAMI.md`** oku.
2. **Sınırını doğrula:** görev metnindeki **SAHİP yollar / DOKUNMA / Kapsam dışı** üçlüsünü oku. Yoksa veya belirsizse **BAŞLAMA — liderden net liste iste** (`§1.1`).
3. **Paylaşılan dizin:** `git add -A`, `git commit -a`, paylaşılan dosyada `git checkout --` ve tam test kapısını koşturmak yasaktır (`§1.5`).

## Vazgeçilmezler (özet — tam liste ve öncelik `.agents/AGENTS.md`)
- `flutter` **`app/` içinde**; `run/test/build`'e **`--dart-define-from-file=env.json`** (yoksa sessizce InMemory'ye düşer); `analyze` bu bayrağı **almaz**.
- **Gizli dosya commit etme** (`env.json`, `key.jks`, `key.properties`, `service_role`). **RLS zorunlu**; XP/kritik ilerleme **server-authoritative**; repository **çift** (`supabase/` + `in_memory/`).
- **Ortamlar ayrıdır:** beta→staging, stable→production; migration local→staging→production terfi eder. Remote reset yasak, production mutasyonu somut kullanıcı GO ister (`docs/ORTAM-MIGRATION-YONETISIMI.md`).
- Kullanıcı metni **Türkçe**; gün sınırı **Europe/Istanbul**.
- **Tek dal `main` — branch/merge/push yok** (kullanıcı istemedikçe); her WP tek ayrık commit, `git add -A` yasak; çakışma dallarla değil **liderin atadığı ayrık SAHİP yolları** ile önlenir (`§1.6`). *(Eski "CI auto-merge / WP-39" planı iptal edildi.)*
- "Tamamlandı" = kod değil; **cihazda güvenilir + kullanıcı beklentisini karşılayan** iş (DoD: `.agents/AGENTS.md §3`).

## Haritalama
| Dosya | Ne |
|---|---|
| `.agents/AGENTS.md` | **Tam kurallar (tek kaynak)** |
| `.agents/skills/worker/SKILL.md` | Uygulayıcı akışı |
| `.agents/skills/planner/SKILL.md` | Planlayıcı akışı |
| `.agents/skills/tester/SKILL.md` | Test akışı (tüm kalite kapıları) |
| `progress.md` | WP kartları + durum (**tek yazar: lider**) |
| `docs/KALITE-PROGRAMI.md` | Kanonik program/plan |
| `docs/AJAN-KULLANIM.md` | Kullanıcının el kitabı |
| `backlog.md` · `project.md` | Backlog · teknik referans |
| `CLAUDE.md` | Claude Code için ikiz giriş noktası (bu dosyaya yönlendirir) |
