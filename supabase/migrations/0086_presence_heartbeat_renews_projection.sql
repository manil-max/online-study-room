-- 0086_presence_heartbeat_renews_projection.sql
-- WP-367 (V51-1): heartbeat artık projeksiyon lease'ini de tazeler.
--
-- Hata: `heartbeat_multi_group_presence()` (0081) lease'i yalnız kanonik
-- `user_live_presence_state` satırında yeniliyordu. Fan-out satırlarının
-- (`group_live_presence`) `lease_expires_at`'i ise `apply_multi_group_presence_state`
-- anında bir kez damgalanıp bir daha hiç tazelenmiyordu.
--
-- İstemci canlılığı **projeksiyon satırından** türetir
-- (`app/lib/data/providers/presence_providers.dart`, `applyPresenceStaleness`
-- önce `lease_expires_at`'e bakar). Shadow birleştirmesinde projeksiyon satırı
-- legacy `presence` satırını ezdiği için taze `updated_at` de kurtarmıyordu.
-- Sonuç: sayaç çalışmaya devam ederken kullanıcı ~70-90 sn sonra hem kendi
-- cihazında hem başkalarında "çalışmıyor"a düşüyordu (sahip cihazda ~80 sn ölçtü).
--
-- Düzeltme yalnız fonksiyon gövdesidir: tablo, kolon, indeks, politika ve grant
-- değişmez. Satır eklenmez/silinmez — var olan fan-out satırlarının süresi
-- kanonik lease ile aynı değere çekilir. Üyelik/fan-out semantiği
-- `apply_multi_group_presence_state`'in işi olarak kalır.
--
-- Geri alma (Rollback): 0081'deki gövdeyi `create or replace` ile geri koyan
-- yeni bir ileri migration. Veri kaybı yoktur; lease'ler kendiliğinden bayatlar.

create or replace function public.heartbeat_multi_group_presence()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_state public.user_live_presence_state%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication_required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 338));
  update public.user_live_presence_state
  set lease_expires_at = clock_timestamp() + interval '70 seconds',
      updated_at = clock_timestamp()
  where user_id = v_uid and status <> 'offline'
  returning * into v_state;

  if not found then
    raise exception 'presence_state_not_active';
  end if;

  -- WP-367: Kanonik lease yenilendi; okuyucuların gördüğü fan-out satırları da
  -- aynı işlemde aynı değere çekilir. Yalnız UPDATE: yeni grup satırı burada
  -- doğmaz, eski satır burada ölmez — üyelik değişimi hâlâ
  -- `apply_multi_group_presence_state`'in sorumluluğundadır.
  update public.group_live_presence
  set lease_expires_at = v_state.lease_expires_at,
      state_version = v_state.state_version,
      projected_at = clock_timestamp()
  where user_id = v_uid;

  return jsonb_build_object(
    'user_id', v_state.user_id,
    'status', v_state.status,
    'state_version', v_state.state_version,
    'lease_expires_at', v_state.lease_expires_at
  );
end;
$$;

revoke all on function public.heartbeat_multi_group_presence()
  from public, anon, authenticated;
grant execute on function public.heartbeat_multi_group_presence()
  to authenticated;
