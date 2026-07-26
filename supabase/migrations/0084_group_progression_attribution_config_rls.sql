-- 0084_group_progression_attribution_config_rls.sql
-- WP-347: Grup progression attribution cutover yapılandırmasını RLS arkasına alır.
--
-- Tablo yalnız SECURITY DEFINER trigger/resolver fonksiyonlarının iç durumudur;
-- istemciye doğrudan erişim verilmez. 0080'deki revoke'lar korunur, bu migration
-- security-advisor'ın bulduğu eksik RLS katmanını ileri yönde tamamlar.
--
-- Geri alma (Rollback): Uygulanmış migration değiştirilmez. Beklenmedik bir
-- server-side erişim sorunu görülürse yalnız gerekli güvenli fonksiyon/policy için
-- ayrı ileri migration yazılır; client erişimi açılmaz.

alter table public.group_progression_attribution_config enable row level security;
revoke all on table public.group_progression_attribution_config from public, anon, authenticated;
