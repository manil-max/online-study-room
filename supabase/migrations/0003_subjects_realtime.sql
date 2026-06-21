-- =====================================================================
-- 0003_subjects_realtime.sql — Dersleri (subjects) Realtime'a ekle
-- Bkz. project.md §3.7 (Dersler/kategoriler).
--
-- `subjects` tablosu + RLS zaten 0001 şemasında kuruldu. Bu migrasyon yalnızca
-- tabloyu Realtime publication'a ekler ki uygulamadaki canlı liste
-- (`.stream()`) ders ekleme/düzenleme/silmeyi anında yansıtsın.
--
-- Çalıştırma: Supabase paneli → SQL Editor → New query → yapıştır → Run.
-- =====================================================================

do $$
begin
  -- Zaten ekliyse tekrar eklemeye çalışıp hata vermesin diye koşullu ekle.
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'subjects'
  ) then
    alter publication supabase_realtime add table public.subjects;
  end if;
end
$$;
