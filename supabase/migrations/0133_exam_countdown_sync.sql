-- 0133_exam_countdown_sync.sql
-- WP-694 — sinav geri sayimi cihazlar arasi senkron.
--
-- 🔴 Bu migration'in varlik sebebi olculdu, varsayilmadi. Gercek bir kullanici
-- "sinav geri sayiminda telefon ve tablette ayri ayri ayarlanmasi gerekiyor,
-- senkronize degil" dedi. Olcum: `app/lib/features/home/dday_prefs.dart` yalniz
-- `SharedPreferences`'a yaziyordu ve bu dizinde geri sayim tablosu YOKTU.
-- Yani ozellik eksikti; bir tercih degildi.
--
-- ---------------------------------------------------------------------------
-- KARARLAR VE GEREKCELERI
-- ---------------------------------------------------------------------------
-- 1. **`id text`, `uuid` degil.** Geri sayim kayitlari buluttan once dogdu ve
--    yerelde `legacy` / `<mikrosaniye>-<sayac>` bicimindeler. Kimligi uuid'e
--    cevirmek yerel kayit ile bulut satirini birbirine baglayamaz hale getirir:
--    ikinci senkronda ayni sinav IKI kez gorunur. Kimlik yalniz kullanici
--    icinde benzersiz oldugu icin birincil anahtar `(user_id, id)` ciftidir.
--
-- 2. **Cakisma: kayit basina son yazan kazanir (`updated_at`).**
--    * *Liste basina* LWW olsaydi telefonda degistirilen ad ile tablette
--      eklenen sinavdan biri SESSIZCE giderdi.
--    * *Yalniz birlesme (union)* olsaydi bir cihazda silinen sinav digerinin
--      bayat kopyasindan geri dogardi.
--    Esitlikte de gelen yazma kazanir; boylece istemci tekrar denedigimde ayni
--    sonuca yakinsar (idempotent).
--
-- 3. **Istemci saati kirpilir.** `p_updated_at` en fazla `now() + 5 dakika`
--    olabilir. Kirpilmasaydi saati 2030'a kurulu tek bir cihaz, kaydi kalici
--    olarak kilitler ve diger cihazin hicbir yazmasi bir daha gecmezdi.
--
-- 4. **Silme SERT silmedir, mezar tasi degil.** Mezar tasi sunucuda tutulsaydi
--    hesap basina sinirsiz buyuyen bir cop birikirdi. Cevrimdisi silmenin
--    hafizasi ISTEMCIDE tutulur (`dday_prefs.dart` -> `pendingDeletes`), sunucu
--    yalniz canli satiri bilir.
--
-- 5. **BACKFILL YOK.** Var olan yerel kayitlar buraya `upsert_exam_countdown`
--    ile ISTEMCIDEN tasinir. Bunun sebebi olculebilirliktir: bu depoda
--    `where ... is null` bicimli bir backfill taze veritabaninda sifir satira
--    dokunur, kapi yesil yanar ve kusur uretimde patlar (0124 dersi). Burada
--    tasima yolu Dart tarafinda ve `countdown_sync_wp694_test.dart` icinde
--    dogrudan olculuyor: "damgasiz yerel kayit ilk acilista yukari tasinir".
--
-- Geri alma (Rollback): veri olustuysa tablo drop EDILMEZ. Istemci sunucusuz
-- moda doner (`examCountdownRepositoryProvider` -> null) ve yalniz yerel
-- kopyayi cizer; tablo read-only anlik goruntu olarak korunur.

create table if not exists public.exam_countdowns (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null check (char_length(id) between 1 and 64),
  -- Ad ISTEGE BAGLIDIR (bos olabilir): arayuz o zaman dile bagli varsayilan
  -- basligi gosterir. Diske kalici bir Turkce kelime yazilmaz.
  -- Ust sinir arayuzun 24 karakterinden genistir: sunucu, arayuz sinirini
  -- gecmis eski bir kaydi REDDEDIP senkronu sessizce durdurmamali.
  name text not null default '' check (char_length(name) <= 64),
  exam_day date not null,
  sort_order integer not null default 0 check (sort_order between 0 and 99),
  is_priority boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists exam_countdowns_user_order_idx
  on public.exam_countdowns (user_id, sort_order, id);

-- Arayuz iki "one cikan" cizemez; tekillik semada sabitlenir, istemci iyi
-- niyetine birakilmaz.
create unique index if not exists exam_countdowns_single_priority_idx
  on public.exam_countdowns (user_id) where is_priority;

alter table public.exam_countdowns enable row level security;
drop policy if exists exam_countdowns_select_self on public.exam_countdowns;
create policy exam_countdowns_select_self on public.exam_countdowns
  for select to authenticated using (user_id = auth.uid());
revoke all on table public.exam_countdowns from public;
grant select on table public.exam_countdowns to authenticated;
revoke insert, update, delete on table public.exam_countdowns
  from authenticated, anon;

-- ---------------------------------------------------------------------------
-- Sinir: proje sahibi karari (2026-08-09) "max 3 tane eklesin".
-- Istemcide de ayni sayi var (`kMaxExamEntries`); sunucu son sozu soyler.
-- ---------------------------------------------------------------------------
create or replace function public._max_exam_countdowns()
returns integer language sql immutable set search_path = public as $$
  select 3;
$$;

create or replace function public.list_exam_countdowns()
returns table (
  id text,
  user_id uuid,
  name text,
  exam_day date,
  sort_order integer,
  is_priority boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql security definer stable set search_path = public as $$
  select c.id, c.user_id, c.name, c.exam_day, c.sort_order, c.is_priority,
         c.created_at, c.updated_at
  from public.exam_countdowns c
  where c.user_id = auth.uid()
  order by c.sort_order asc, c.id asc;
$$;

create or replace function public.upsert_exam_countdown(
  p_id text,
  p_name text,
  p_exam_day date,
  p_sort_order integer,
  p_is_priority boolean,
  p_updated_at timestamptz
)
returns public.exam_countdowns
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_existing public.exam_countdowns%rowtype;
  v_row public.exam_countdowns%rowtype;
  v_stamp timestamptz;
  v_name text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_id is null or char_length(btrim(p_id)) = 0 then
    raise exception 'exam_countdown_id_required';
  end if;
  if p_exam_day is null then raise exception 'exam_countdown_day_required'; end if;

  -- Istemci saati kirpilir (karar 3).
  v_stamp := least(coalesce(p_updated_at, now()), now() + interval '5 minutes');
  v_name := left(coalesce(p_name, ''), 64);

  select * into v_existing from public.exam_countdowns
  where user_id = v_uid and id = p_id for update;

  if not found then
    if (select count(*) from public.exam_countdowns where user_id = v_uid)
       >= public._max_exam_countdowns() then
      -- 🔴 Sessizce yutulmaz. Istemci bunu yakalar, kaydi "senkron oldu" diye
      -- isaretlemez ve bir sonraki turda tekrar dener.
      raise exception 'exam_countdown_limit_reached';
    end if;
  elsif v_existing.updated_at > v_stamp then
    -- Bayat yazma: kayit basina LWW. Hata degil, sessiz basarisizlik da degil;
    -- istemciye SUNUCUDAKI kazanan satir doner.
    return v_existing;
  end if;

  if coalesce(p_is_priority, false) then
    -- Tekil kismi indeks catismasin diye once eski one cikan temizlenir.
    update public.exam_countdowns
      set is_priority = false, updated_at = greatest(updated_at, v_stamp)
      where user_id = v_uid and id <> p_id and is_priority;
  end if;

  insert into public.exam_countdowns (
    user_id, id, name, exam_day, sort_order, is_priority, updated_at
  ) values (
    v_uid, p_id, v_name, p_exam_day,
    least(greatest(coalesce(p_sort_order, 0), 0), 99),
    coalesce(p_is_priority, false), v_stamp
  )
  on conflict (user_id, id) do update set
    name = excluded.name,
    exam_day = excluded.exam_day,
    sort_order = excluded.sort_order,
    is_priority = excluded.is_priority,
    updated_at = excluded.updated_at
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.delete_exam_countdown(p_id text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  delete from public.exam_countdowns where user_id = v_uid and id = p_id;
  -- Yok olan kaydi silmek HATA DEGILDIR: istemci cevrimdisi silme isaretini
  -- tekrar tekrar gonderebilir; ikinci deneme de basarili sayilmali, yoksa
  -- isaret hic temizlenmez ve her acilista bir daha denenir.
  return true;
end;
$$;

revoke all on function public._max_exam_countdowns() from public;
revoke all on function public.list_exam_countdowns() from public;
revoke all on function public.upsert_exam_countdown(
  text, text, date, integer, boolean, timestamptz) from public;
revoke all on function public.delete_exam_countdown(text) from public;
grant execute on function public.list_exam_countdowns() to authenticated;
grant execute on function public.upsert_exam_countdown(
  text, text, date, integer, boolean, timestamptz) to authenticated;
grant execute on function public.delete_exam_countdown(text) to authenticated;
