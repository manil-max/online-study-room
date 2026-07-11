-- 0023_notification_center.sql
-- Bildirim Merkezi: kişisel çalışma hatırlatıcıları ve duyuru okundu takibi.
-- Tekrar-çalıştırılabilir (idempotent): `if not exists` ve `drop policy if exists`.

-- ---------------------------------------------------------------------------
-- Çalışma hatırlatıcıları — kullanıcının kendi zamanlanmış hatırlatıcıları.
-- Yerel bildirim olarak da planlanır; tablo cihazlar arası kalıcılık sağlar.
-- weekdays: ISO gün numaraları (1=Pazartesi .. 7=Pazar); boş dizi = her gün.
-- ---------------------------------------------------------------------------
create table if not exists public.study_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text,
  hour int not null check (hour between 0 and 23),
  minute int not null check (minute between 0 and 59),
  weekdays int[] not null default '{}',
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_study_reminders_user
  on public.study_reminders (user_id, created_at desc);

alter table public.study_reminders enable row level security;

-- Kullanıcı yalnız kendi hatırlatıcılarını görür ve yönetir.
drop policy if exists study_reminders_owner_all on public.study_reminders;
create policy study_reminders_owner_all on public.study_reminders
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Duyuru okundu takibi — Bildirim Merkezi'ndeki okunmamış rozetleri için.
-- Duyurunun kendisi 0021'deki `announcements` tablosunda; burada yalnız
-- kullanıcı bazında okundu kaydı tutulur.
-- ---------------------------------------------------------------------------
create table if not exists public.announcement_reads (
  user_id uuid not null references auth.users (id) on delete cascade,
  announcement_id uuid not null
    references public.announcements (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (user_id, announcement_id)
);

alter table public.announcement_reads enable row level security;

-- Kullanıcı yalnız kendi okundu kayıtlarını görür ve yazar.
drop policy if exists announcement_reads_owner_all on public.announcement_reads;
create policy announcement_reads_owner_all on public.announcement_reads
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
