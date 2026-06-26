-- =====================================================================
-- 0010_drop_session_group_id.sql — study_sessions.group_id kaldırma
-- Bkz. progress.md §1B (K8, K9, K10). Oturum artık yalnızca kullanıcıya
-- aittir; grup istatistiği study_sessions ⨝ group_members join'iyle
-- hesaplanır.
--
-- ⚠️ SIRALAMA KRİTİK: politika → index → kolon.
-- Kolonu önce düşürmeye çalışırsan politika bağımlılığı hata verir.
--
-- ⚠️ presence tablosu group_id'yi KORUR — ona dokunma (K9).
-- ⚠️ idx_sessions_user kalır (K9).
--
-- Sıra: 0008 → 0009 → 0010 → 0011 (zorunlu).
--
-- Çalıştırma: Supabase paneli → SQL Editor → New query → yapıştır → Run.
-- =====================================================================

-- 1) Önce kolona bağlı SELECT politikayı group_id'siz yeniden yaz
--    (artık can_see_user_sessions helper'ını kullanır — 0009'da oluşturuldu)
drop policy if exists sessions_select on public.study_sessions;
create policy sessions_select on public.study_sessions
  for select to authenticated
  using (public.can_see_user_sessions(user_id));

-- 2) group_id'ye bağlı index'i düşür
drop index if exists public.idx_sessions_group;

-- 3) Kolonu düşür (NOT NULL FK idi; veri diğer kolonlarda durur)
--    Tarihsel kayıp kabul edildi (K10): eski satırların orijinal group_id'si
--    kaybolur; grup ataması üyelik penceresinden yeniden kurulur.
alter table public.study_sessions drop column if exists group_id;
