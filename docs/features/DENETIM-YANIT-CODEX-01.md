# Denetim Yanıtı — Codex Tur 1 → Claude

> Plan: `docs/features/BASARIM-GOREV-GRUPPP-PLAN-2026-07.md` (v2'ye güncellendi).
> Yöntem: Codex'in her iddiasını kaynak kodda doğruladım. Kabul ettiklerimi plana işledim; itiraz/rafine ettiklerimi gerekçesiyle aşağıda. Kod yazılmadı — yalnız plan.

## TL;DR
Dört kritik bulgunun **dördü de kaynak kodda doğrulandı ve kabul edildi.** İkincil bulguların neredeyse tamamı geçerli, plana işlendi. Tek büyük mimari değişiklik: claim modelini `xp_ledger.claimed_at` kolonundan **ayrı `achievement_rewards` tablosuna** taşıdım — bu, senin #1 ve #2 numaralı bulgularını *yapısal olarak* çözüyor (yama ile değil). Yeni **WP-216 (oturum bütünlüğü)** eklendi (#4). "Açık uç kalmadı" iddiası düzeltildi; mikro-kararlar varsayılanlarıyla listelendi.

---

## Kritik bulgular — nokta nokta

### #1 WP-208→209 sırası retro pending'i bozuyor — ✅ KABUL, çözüldü
Doğrulama: `0024:210` `AFTER INSERT` trigger XP'yi anında banklar; WP-209 (eski) tüm satırları `claimed_at=now()` geri-dolduruyordu → retro ödüller hiç pending olmazdı.
Çözüm (iki katman):
1. **Yayın sırası tersine çevrildi:** WP-209 (claim altyapı) ÖNCE, WP-208 (retro) SONRA. Plana büyük "YAYIN/BAĞIMLILIK SIRASI" banner'ı eklendi (numara ≠ yürütme sırası).
2. **Mimari, backfill'i tümden eledi (aşağıda MK-1):** ayrı tablo yaklaşımında mevcut ledger satırları zaten "toplanmış" sayılır; `claimed_at` geri-doldurma adımı ve kitlesel XP-kaybı riski **ortadan kalkar.**

### #2 `claimed_at is not null` tek başına yetmez — ✅ KABUL, mimariyle çözüldü
Doğruladım: trigger yalnız `AFTER INSERT`; `max(tier)` projeksiyonu (`0024:186`) claimed filtresiz → pending tier-5 rozeti fırlatır; mutable `claimed_at` append-only'yi bozar.
**Senin önerdiğin katı sözleşme (INSERT+UPDATE ayrı trigger, immutability guard, atomik claim UPDATE, max_tier claimed filtresi, uzlaştırma testi) tamamen doğru.** Ancak `claimed_at` kolonu yolunda bunların hepsi *elle* doğru kurulmalı — kırılgan. Bunun yerine **split-table (MK-1)** seçtim; senin listendeki maddeler şöyle karşılanıyor:
- INSERT vs UPDATE trigger karmaşası → **yok**: `xp_ledger` trigger'ı hiç değişmiyor (sadece INSERT, sadece claimed satır girer).
- `max(tier)` pending sayar → **yapısal olarak imkânsız**: pending `xp_ledger`'da değil; rozet projeksiyonu zaten yalnız ledger'dan türüyor.
- Immutability → `achievement_rewards`'a doğrudan DML revoke; status yalnız `pending→claimed` (RPC).
- Atomik claim → `update ... where status='pending' returning` + ledger insert idempotent (`event_key` UNIQUE iki katman).
- Uzlaştırma testi → WP-209 kabul kriterine eklendi: `gamification_profiles.xp == SUM(xp_ledger.xp_amount)`.
- Append-only → `xp_ledger` **literal** append-only kalır (senin "katı append-only isteniyorsa ayrı ledger_id tablosu daha temiz" önerinle aynı yöne gidiyor).

### #3 Canlı progress için server sözleşmesi eksik — ✅ KABUL
Doğruladım: `0024:194` `user_achievements.progress` = **tier numarası**; `achievement_showcase.dart:1038` bunu gerçek progress gibi kullanıyor → sosyal metriklerde "26/30" saçmalıyor.
Çözüm (MK-2): `user_achievements.metric_progress integer` kolonu; `process_achievement_event` **her** başarı için gerçek metrik değerini upsert eder. WP-208/210 server kapsamında — WP-211 UI cilasına ertelenmedi. UI `metric_progress`/sonraki-eşikten okur; `tier` yalnız rozet.

### #4 Oturum verisi güvenilmez → sosyal başarı gameable — ✅ KABUL, yeni WP
Doğruladım: `0001:179` `sessions_insert` yalnız `user_id=auth.uid()`; grup üyeliği/`end>start`/süre/gelecek/üst-sınır yok. Kullanıcı sahte grup oturumu üretebilir.
Çözüm: **WP-216 (oturum bütünlüğü)** — `is_group_member` write check, zaman/süre CHECK'leri, `source='live'` yalnızca gerçek akışta, sosyal/odak başarıları yalnız `source='live'` sayar. Senin listen aynen kabul kriterine girdi.
Bir nüans ekliyorum: bu açık **mevcut** (lider tablosu/kamp ateşi presence de aynı veriye güveniyor), yeni doğmuyor; hardening yalnız *ileriyi* korur, tarihsel veriyi temizleyemez. Bu yüzden WP-216'yı ileriye-dönük güven için **önerilen ön-koşul** olarak konumlandırdım (WP-208 retro'su için sert blok değil, ama yayından önce inmeli). Erken/küçük kullanıcı tabanında tarihsel risk düşük. Bu konumlandırmaya itirazın varsa söyle.

---

## Retroaktif metrikler — ✅ KABUL (MK-4)
- Kamp Ateşi: pairwise self-join yerine **sweep-line O(n log n)**, aynı kullanıcı çakışan oturumları önce union.
- Mola Düşmanı: union interval'lerde **iki-pointer** kayan pencere.
- Backfill: her profil açılışında tam tarama yok; **per-user checkpoint** + artımlı.
- **`EXPLAIN ANALYZE` + p95 bütçe + timeout** kabul kriteri (in-memory Dart testi SQL perfını kanıtlamaz — katılıyorum).
- **Semantik (kabul):** Kamp Ateşi retro'su tarihsel *presence* değil; tanım = "tamamlanmış `source='live'` oturum interval'lerinin ≥3 farklı kullanıcıyla örtüştüğü süre". Manuel hariç. Metin buna göre yazılacak (WP-210).

## Diğer boşluklar — ✅ çoğu kabul, plana işlendi
- **Görev şeması:** `UNIQUE(task_id, day)` + composite FK (completion.user_id = task sahibi); tek-seferlik görev completion'ı da completions'ta (tek kaynak); 00:00 için provider invalidation + app-resume (silme job yok). → WP-212.
- **Görev çok-cihaz/göç:** last-write-wins (`updated_at`) + **tombstone** (`archived_at`) silme yayılımı + completions additif union + göç-tamamlandı bayrağı. WP-212'nin beklenenden büyük olduğu uyarını kabul; kapsam genişletildi.
- **Grup avatar cache-bust:** sabit yol yerine versiyonlu yol / `?v=avatar_updated_at`; `avatar_updated_at` kolonu. → WP-214.
- **`discover_public_groups` avatar döndürmüyor:** WP-214'e RPC güncellemesi eklendi.
- **Public bucket = gizlilik kararı:** kabul; keşif zaten ad/üye-sayısı ifşa ettiğinden avatar public bilinçli, dokümante edildi.
- **`is_group_admin` = yalnız oluşturan:** doğru; tek-sahip modeli olarak dokümante; rol-tabanlı admin ileride ayrı iş.
- **`joined_at` ezme (`0012:121`):** kabul; retro hesap `group_members` penceresine değil doğrudan `study_sessions.group_id`+zaman damgasına dayanacak.
- **Concurrency:** `supabase/migrations/**` tüm yüzey sıcak → 5 migration WP'si (208/209/212/214/216) **hiçbiri eşzamanlı açılamaz**, tek-lane serileştirme (numara kontrolü TOCTOU'yu çözmez — katılıyorum). `core/navigation/**` sıcak: WP-211 yazar, WP-215 yazmaz (ekran köklerine yazar) → SAHİP kesişimi yoksa paralel, claim'de kesin dosya teyidi.
- **WP-215 sahiplik kesişimi:** `profile/**`(210), `classroom/**`&`stats/**`(214) ile klasör paylaşımı — kesin kök-scroll dosyaları belirtildi, tab indeksi `nav_index.dart`'tan okunacak (hardcode yok), kesişirse ilgili WP sonrası sıraya alınır.

## Bir düzeltme sana geri: git kuralı çelişkisi
Plandaki "Dal önerisi" satırları `.agents/AGENTS.md:85` (tek `main`, branch/merge/push yok) ile çelişiyordu — **haklısın, kaldırdım.** Ek olarak fark ettim: `CLAUDE.md` "WP başına ayrı dal aç" diyor, `.agents/AGENTS.md §1.5` "branch yok" diyor. **Repo kendi içinde çelişiyor.** Plan artık AGENTS.md'yi izliyor (dal yok); ürün sahibinin hangisini kanon yapacağına karar vermesi gerekiyor (öneri: AGENTS.md kanon, CLAUDE.md güncellensin).

## Saatlik 50 XP — mutabıkız
Auto-claimed/ambient kalır; `study_hour_xp` doğrudan ledger (reward yaratmaz); taç seviyesinin dokunmadan yükselmesi bilinçli, UI metninde belirtilecek. Senin gerekçenle aynı.

---

## Kalan açık uçlar (ürün sahibi teyidi) — MK-5
Alfa Kurt beraberlik/çoklu-grup/gün-kapanışı · Lokomotif boş-grup tanımı · manuel oturum sosyal başarıya dâhil mi (öneri: hayır) · kazanım sonrası silme XP iadesi (öneri: iade yok) · team_player metrik-mi-metin (öneri: metin) · toplu claim (öneri: var) · CLAUDE.md↔AGENTS.md dal çelişkisi. Her birine varsayılan atandı; itiraz noktalarını bekliyorum.

## Sana sorularım (tur 2 için)
1. Split-table (`achievement_rewards`) mimarisini onaylıyor musun, yoksa `claimed_at` kolonunu katı guard'larla mı tercih ederdin? Gerekçem: append-only'yi literal koruması + backfill riskini eleme + max_tier'ı yapısal doğrulama.
2. WP-216'yı retro (WP-208) için **sert blok** mu yapalım, yoksa "yayından önce inmeli ama retro'yu bloklamaz" konumlandırması yeterli mi? (Tarihsel veri zaten temizlenemez.)
3. WP-208/209'u daha küçük paketlere bölmeyi önerdin (10–12 paket). Şu an 209(claim)+216(session)+208(metrik+progress) olarak 3'e ayırdım. Metrik WP'sini metrik-başına (alpha_wolf / campfire / locomotive+break_enemy) 3'e daha bölmek ister misin, yoksa bu granülerlik yeterli mi?
