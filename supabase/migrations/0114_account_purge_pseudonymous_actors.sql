-- 0114_account_purge_pseudonymous_actors.sql
-- WP-464 Faz 2: hesap silmeyi blokleyen `restrict` FK'leri cozer, kaniti
-- TAKMA KIMLIKLE korur.
--
-- SAHIP KARARI (2026-07-31): "takma kimlikle korunsun, set null + hash yap."
-- `docs/HESAP-SILME-RETENTION-KARARI.md` §5'te bos duran secim bu turda
-- karara baglandi; asagisi o kararin uygulamasidir, uydurma degildir.
--
-- 🔴 Cozulen sorun (WP-464 Faz 1'de kodda dogrulandi): `public` semasindan
-- `auth.users`'a giden YEDI adet `not null` + `on delete restrict` FK
-- `auth.admin.deleteUser`'i FK ihlaliyle dusuruyordu. Yani `0113` zamanlayiciyi
-- baglasa bile bu hesaplar HIC silinemiyordu; is 5 denemeyi yakip terminal
-- `failed` oluyordu. En genisi `feedback_ticket_messages.sender_id`:
-- `sender_role` 'user' de olabildigi icin destek biletine tek mesaj yazmis
-- SIRADAN kullanici da silinemiyordu.
--
-- Cozum deseni (her tablo icin ayni):
--   1. `<sutun>_hash` takma kimlik sutunu eklenir ve mevcut satirlar doldurulur
--   2. hash `not null` yapilir -> kanit her zaman atfedilebilir kalir
--   3. kimlik sutunu nullable yapilir
--   4. FK `on delete set null` olarak yeniden kurulur
--   5. tetikleyici hash'i canli tutar
--
-- Silme aninda ne olur: `deleteUser` -> FK kimlik sutununu NULL'lar -> satir
-- ve `_hash` YERINDE KALIR. Kanit kaybolmaz, ham kimlik gider.
--
-- Hash, `0113`teki `account_purge_audit.user_hash` ile AYNI insadir
-- (sha256(uid) hex). Bu kasitlidir: operasyon "bu hesap silindi mi" ile "bu
-- yaptirimi kim verdi" sorularini PII olmadan eslestirebilsin.
--
-- Geri alma (Rollback): bu migration veri kaybettirmez ama geri alinmasi
-- kimligi GERI GETIRMEZ (hash tek yonludur). Geri almak gerekirse FK'leri
-- `restrict`e cevirmek yerine ileri bir migration yazin.

-- ---------------------------------------------------------------------------
-- 1. Takma kimlik uretici
-- ---------------------------------------------------------------------------
-- `0113` ayni ifadeyi satir ici kullaniyor; buradaki tek tanim onun yerine
-- gecmez ama ayni cikti verir ve `040` bunu iddia ile sabitler.
-- `text::bytea` cast'i PostgreSQL'de YOKTUR; `convert_to(..., 'UTF8')` sart.
create or replace function public.pseudonymous_user_hash(p_user_id uuid)
returns text
language sql
immutable
set search_path = pg_catalog, public
as $$
  select encode(sha256(convert_to(p_user_id::text, 'UTF8')), 'hex');
$$;

comment on function public.pseudonymous_user_hash(uuid) is
  'WP-464: silinen hesabin kanitta birakilan takma kimligi. sha256(uid) hex, '
  '`account_purge_audit.user_hash` ile ayni insa.';

-- ---------------------------------------------------------------------------
-- 2. Yedi tabloyu doneme sok
-- ---------------------------------------------------------------------------
do $migration$
declare
  v_row record;
  v_fk text;
  v_attnum smallint;
  v_fn text;
begin
  for v_row in
    select *
    from (values
      ('admin_audit_logs',         'admin_id',   'admin_hash'),
      ('announcements',            'created_by', 'created_by_hash'),
      ('feedback_ticket_notes',    'admin_id',   'admin_hash'),
      ('feedback_ticket_messages', 'sender_id',  'sender_hash'),
      ('group_bans',               'banned_by',  'banned_by_hash'),
      ('moderation_name_resets',   'reset_by',   'reset_by_hash'),
      ('moderation_sanctions',     'actor_id',   'actor_hash')
    ) as t(tbl, id_col, hash_col)
  loop
    -- Tablo gercekten var mi (zincir bozulursa sessizce yanlis yapma).
    if to_regclass('public.' || quote_ident(v_row.tbl)) is null then
      raise exception 'wp464_missing_table_%', v_row.tbl;
    end if;

    -- 1. hash sutunu
    execute format(
      'alter table public.%I add column if not exists %I text',
      v_row.tbl, v_row.hash_col
    );

    -- 2. mevcut satirlari doldur
    execute format(
      'update public.%I set %I = public.pseudonymous_user_hash(%I) '
      'where %I is null and %I is not null',
      v_row.tbl, v_row.hash_col, v_row.id_col, v_row.hash_col, v_row.id_col
    );

    -- 3. hash zorunlu: kanit her zaman atfedilebilir kalsin
    execute format(
      'alter table public.%I alter column %I set not null',
      v_row.tbl, v_row.hash_col
    );

    -- 4. kimlik sutunu artik null olabilir (set null'in on kosulu)
    execute format(
      'alter table public.%I alter column %I drop not null',
      v_row.tbl, v_row.id_col
    );

    -- 5. eski FK'yi ADIYLA DEGIL yapisiyla bul: isimler uretilmis olabilir
    select a.attnum into v_attnum
    from pg_attribute a
    where a.attrelid = ('public.' || quote_ident(v_row.tbl))::regclass
      and a.attname = v_row.id_col
      and not a.attisdropped;

    select con.conname into v_fk
    from pg_constraint con
    where con.conrelid = ('public.' || quote_ident(v_row.tbl))::regclass
      and con.contype = 'f'
      and con.confrelid = 'auth.users'::regclass
      and con.conkey = array[v_attnum];

    if v_fk is null then
      raise exception 'wp464_fk_not_found_%_%', v_row.tbl, v_row.id_col;
    end if;

    execute format(
      'alter table public.%I drop constraint %I', v_row.tbl, v_fk
    );
    execute format(
      'alter table public.%I add constraint %I foreign key (%I) '
      'references auth.users(id) on delete set null',
      v_row.tbl, v_fk, v_row.id_col
    );

    -- 6. hash'i canli tutan tetikleyici.
    -- 🔴 `on delete set null` kimlik sutununu NULL'larken satir UPDATE'i
    -- tetikler. Tetikleyici o anda hash'i EZMEMELI: yalniz kimlik doluyken
    -- yeniden hesaplar, NULL'a duserken mevcut hash'e dokunmaz.
    v_fn := '_sync_' || v_row.tbl || '_' || v_row.hash_col;
    execute format(
      'create or replace function public.%I() returns trigger '
      'language plpgsql as $fn$ begin '
      '  if new.%I is not null then '
      '    new.%I := public.pseudonymous_user_hash(new.%I); '
      '  end if; '
      '  return new; '
      'end; $fn$;',
      v_fn, v_row.id_col, v_row.hash_col, v_row.id_col
    );

    execute format('drop trigger if exists %I on public.%I', v_fn, v_row.tbl);
    execute format(
      'create trigger %I before insert or update on public.%I '
      'for each row execute function public.%I()',
      v_fn, v_row.tbl, v_fn
    );
  end loop;
end
$migration$;
