-- 0068_revoke_push_dispatch_config_rpc.sql
-- WP-268: 0067'nin staging post-check'te yakalanan eski doğrudan EXECUTE grant'lerini kapatır.
--
-- 0067'nin `PUBLIC` revoke'u, daha önce `authenticated` rolüne doğrudan verilmiş
-- EXECUTE yetkisini kaldırmaz. Bu ileri migration, istemcilerin dispatcher endpointi
-- veya secret'ını değiştirebilmesini engeller ve RPC'yi yalnızca service_role'a bırakır.
--
-- Geri alma (Rollback): Yalnızca acil, kontrollü bir service erişim sorunu için yeni
-- ileri migration ile service_role EXECUTE yetkisi yeniden verilir; authenticated/anon
-- erişimi geri açılmaz.

revoke all on function public.configure_push_dispatch(text, text) from public;
revoke all on function public.configure_push_dispatch(text, text) from anon, authenticated;
grant execute on function public.configure_push_dispatch(text, text) to service_role;
