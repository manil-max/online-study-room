-- =====================================================================
-- 0004_group_admin.sql — Sınıf yönetimi (admin) RLS politikaları
-- Bkz. project.md §3.8. Admin = sınıfı oluşturan (groups.created_by).
--
-- Olmadan: ad değiştirme / kod yenileme / üye çıkarma / sınıf silme RLS'e
-- takılır. "Sınıftan çık" (kişinin kendini silmesi) zaten 0001'de vardı.
--
-- Çalıştırma: Supabase paneli → SQL Editor → New query → yapıştır → Run.
-- =====================================================================

-- Yardımcı: çağıran kullanıcı bu sınıfın admini (oluşturanı) mı?
create or replace function public.is_group_admin(gid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.groups where id = gid and created_by = auth.uid()
  );
$$;

-- groups: admin sınıfı güncelleyebilir (ad / davet kodu) ve silebilir.
drop policy if exists groups_update on public.groups;
create policy groups_update on public.groups
  for update to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

drop policy if exists groups_delete on public.groups;
create policy groups_delete on public.groups
  for delete to authenticated
  using (created_by = auth.uid());

-- group_members: kişi kendini çıkarabilir (mevcut) VEYA admin başkasını çıkarabilir.
drop policy if exists members_delete on public.group_members;
create policy members_delete on public.group_members
  for delete to authenticated
  using (user_id = auth.uid() or public.is_group_admin(group_id));
