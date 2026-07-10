# Codex görevi — Güvenlik Hardening (presence üyelik doğrulama) + (ops.) release sertleştirme

Sen Codex'sin ve **Claude ile AYNI ANDA, paralel** çalışıyorsun. Claude FAZ 2H'yi
(eksiksiz sayaç/zamanlayıcı — classroom timer widget'ları + `study_providers.dart`) yapıyor.
Çakışmayı önlemek için **sadece aşağıdaki dosyalara yaz**; başkasına dokunma.

## Proje bağlamı
- Flutter + Supabase. Kök: `app/`. Migration'lar: `supabase/migrations/` (en son **0012**).
- RLS aktif. `is_group_member(gid)` helper'ı **0008 sonrası** yalnız AKTİF üyeliği sayar
  (`left_at is null`). Grup katılımı **0012**'de SECURITY DEFINER RPC'lere taşındı; doğrudan
  istemci insert'i kapatıldı. 0013 aynı felsefeyle **presence** yazımını sıkılaştırır.
- Migration çalıştırma **kullanıcının işi** (Supabase paneli → SQL Editor). Sen sadece geçerli
  SQL dosyasını yaz. `progress.md` içinde **"⚡ PARALEL ÇALIŞMA"** ve **"Tur 2 / Güvenlik
  hardening"** bölümlerini oku.

## SENİN SAHİP OLDUĞUN DOSYALAR (yalnız bunlara yaz)
- **YENİ:** `supabase/migrations/0013_presence_membership_hardening.sql`
- Gerekirse: `supabase/README.md` (migration listesine 0013'ü ekle)
- **Opsiyonel ayrı mini faz (aşağıda):** `.github/workflows/release.yml`,
  `app/android/app/build.gradle.kts`, `app/lib/features/updater/*`

## ASLA DOKUNMA (Claude'un / diğer turların alanı)
`app/lib/features/classroom/*` (timer widget'ları dâhil), `app/lib/data/providers/study_providers.dart`,
`app/lib/data/providers/presence_providers.dart`, `app/lib/features/home/*`, `app/lib/features/profile/*`,
diğer migration dosyaları (0001–0012 — **değiştirme**, sadece yeni 0013 ekle).

---

## ASIL İŞ — 0013: presence üyelik doğrulama

### Açık (mevcut zafiyet)
`0001`'deki presence yazma politikaları yalnız **kimlik** kontrol ediyor, **üyelik** değil:
```sql
-- presence_upsert (insert):  with check (user_id = auth.uid())
-- presence_update (update):  using/with check (user_id = auth.uid())
```
`group_id`'nin gerçekten kullanıcının AKTİF üyesi olduğu bir grup olduğu **kontrol edilmiyor**.
Sonuç: kötü niyetli bir kullanıcı `presence` satırına **üyesi olmadığı** bir `group_id` yazıp o
grupta "çalışıyor" görünebilir (`presence_select` = `is_group_member(group_id)` olduğu için o
grubun üyeleri bu sahte durumu görür). 0012'de grup katılımı için yapılan sunucu-taraflı zorlamanın
presence karşılığı eksik.

### Çözüm (0013)
`presence_upsert` ve `presence_update` politikalarının `with check`'ine üyelik şartı ekle. Kişi
yalnız **kendi** satırını ve yalnız **aktif üyesi olduğu** bir gruba (veya grupsuzsa `null`) yazabilsin.

Dosya: `supabase/migrations/0013_presence_membership_hardening.sql` — 0012 dosyasının başlık/stil
kalıbına uy (açıklayıcı header + `drop policy if exists` → `create policy`). Örnek gövde:

```sql
-- presence yazımı: kişi yalnız KENDİ satırını ve yalnız AKTİF üyesi olduğu gruba yazabilir.
-- (group_id null = grupsuz; buna izin verilir ki offline/çıkış durumu kırılmasın.)
drop policy if exists presence_upsert on public.presence;
create policy presence_upsert on public.presence
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (group_id is null or public.is_group_member(group_id))
  );

drop policy if exists presence_update on public.presence;
create policy presence_update on public.presence
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and (group_id is null or public.is_group_member(group_id))
  );
```

`presence_select` (0001) zaten `is_group_member(group_id)` kullanıyor → **dokunma**, doğru.

### Doğrulama / kabul kriteri
- Migration Supabase'de hatasız çalışır (kullanıcı uygular).
- Aktif üye kendi presence'ını kendi grubuna yazabilir (uygulama normal çalışır).
- Kullanıcı, üyesi OLMADIĞI bir `group_id` ile presence insert/update denerse RLS reddeder.
- `left_at` set edilmiş (gruptan çıkmış) kullanıcı o gruba presence yazamaz (is_group_member false).
- **Tuzak:** `is_group_member` SECURITY DEFINER + `stable`; policy içinde çağrılabilir. `group_id`
  null durumunu MUTLAKA ayrı tut (yoksa grupsuz kullanıcının offline yazması kırılır).

### progress.md
Yalnız **kendi** güvenlik-hardening satırını işaretle/güncelle (kısa "Uygulandı (2026-07-10)" notu).
**2H bölümüne dokunma.** progress.md aynı çalışma ağacında; çakışmayı önlemek için yalnız kendi
bölümünü düzenle.

---

## OPSİYONEL — release sertleştirme (yalnız asıl iş bitince, ayrı iş)
Sadece 0013 tamamlandıktan sonra ve zaman varsa. `progress.md` FAZ 5.1'e göre kontrol et:
- `.github/workflows/release.yml` — imza secret'ları, `versionCode` = tag sayısı, SHA-256 üretimi
  doğru mu; sertleştirilecek nokta var mı (ör. release'e yalnız `app-release.apk` yüklensin).
- `app/android/app/build.gradle.kts` — release imza config'i, minify/shrink.
- `app/lib/features/updater/*` — indirilen APK'nın SHA-256 doğrulaması + asset adı sıkı eşleşme
  zaten var; ek sertleştirme gerekiyor mu değerlendir.
Bu mini faz Claude'un alanına (classroom/timer) **hiç girmez** → güvenli.
