-- =====================================================================
-- 0009_session_visibility.sql — Oturum görünürlüğü helper'ı
-- Bkz. progress.md §1B (K2). group_id kaldırılınca study_sessions
-- SELECT politikası is_group_member(group_id) kullanamaz. Yeni helper:
-- "bir kullanıcının oturumunu görebilirim ⇔ kendiminkidir VEYA
--  kendisiyle ortak bir grubun AKTİF üyesiyim."
--
-- SECURITY DEFINER: RLS recursion'ı önlemek için (group_members'a
-- erişim RLS'siz yapılır).
--
-- Sıra: 0008 → 0009 → 0010 → 0011 (zorunlu).
--
-- Çalıştırma: Supabase paneli → SQL Editor → New query → yapıştır → Run.
-- =====================================================================

create or replace function public.can_see_user_sessions(target uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select target = auth.uid() or exists (
    select 1 from public.group_members me
    join public.group_members other on other.group_id = me.group_id
    where me.user_id = auth.uid() and me.left_at is null
      and other.user_id = target
      -- other.left_at filtrelenmez → ayrılan üyenin geçmiş oturumları
      -- kalan üyelere görünür kalır
  );
$$;
