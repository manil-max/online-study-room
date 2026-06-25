-- 0007_group_daily_totals.sql
-- Grup geneli istatistikler için sunucu tarafı günlük agregasyon (OPTIMIZATIONS.md F1).
--
-- Amaç: Canlı sınıf ekranı/leaderboard/trend, daha önce sınıfın TÜM oturumlarını
-- realtime akıtıp istemcide işliyordu (oturum sayısıyla sınırsız büyür). Bunun
-- yerine bu RPC, oturumları sunucuda (user_id, gün) bazında toplar; istemciye
-- inen veri yalnızca (üye × aktif gün) kadar olur.
--
-- Gün sınırı: Europe/Istanbul. Uygulama Türkiye merkezli; istemcideki gün
-- hesabıyla (cihaz yerel saati) tutarlı olması için sabit bu saat dilimi kullanılır.
--
-- Güvenlik: SECURITY INVOKER → çağıranın study_sessions üzerindeki RLS'i geçerli.
-- Yani kullanıcı yalnızca üyesi olduğu grupların verisini görebilir (mevcut
-- SELECT politikasıyla aynı erişim; ek yetki açılmaz).

create or replace function public.group_daily_totals(p_group_id uuid)
returns table (
  user_id uuid,
  day date,
  seconds bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    s.user_id,
    (s.start_time at time zone 'Europe/Istanbul')::date as day,
    sum(s.duration_seconds)::bigint as seconds
  from study_sessions s
  where s.group_id = p_group_id
  group by s.user_id, (s.start_time at time zone 'Europe/Istanbul')::date;
$$;

grant execute on function public.group_daily_totals(uuid) to authenticated;
