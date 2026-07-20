-- WP-226 deterministic local fixture.
-- Synthetic identities only; no production data, email, token, or secret.

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'local-alpha@example.invalid',
    crypt('local-only-password', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Local Alpha"}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'local-beta@example.invalid',
    crypt('local-only-password', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Local Beta"}'::jsonb,
    now(),
    now()
  )
on conflict (id) do nothing;

insert into public.groups (id, name, invite_code, created_by, created_at)
values (
  '20000000-0000-0000-0000-000000000001',
  'Local Recovery Group',
  'LOCAL001',
  '10000000-0000-0000-0000-000000000001',
  now()
)
on conflict (id) do nothing;

insert into public.group_members (group_id, user_id, role, joined_at)
values
  (
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'admin',
    now() - interval '1 day'
  ),
  (
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    'member',
    now() - interval '1 day'
  )
on conflict (group_id, user_id) do nothing;

-- Two equal, overlapping sessions exercise both allowed source values without
-- closing/finalizing a historical day during seed replay.
with day_bounds as (
  select (date_trunc('day', timezone('Europe/Istanbul', now()))
    + interval '8 hours') at time zone 'Europe/Istanbul' as started_at
)
insert into public.study_sessions (
  id,
  user_id,
  start_time,
  end_time,
  duration_seconds,
  source
)
select
  '30000000-0000-0000-0000-000000000001'::uuid,
  '10000000-0000-0000-0000-000000000001'::uuid,
  started_at,
  started_at + interval '1 hour',
  3600,
  'live'
from day_bounds
union all
select
  '30000000-0000-0000-0000-000000000002'::uuid,
  '10000000-0000-0000-0000-000000000002'::uuid,
  started_at,
  started_at + interval '1 hour',
  3600,
  'manual'
from day_bounds
on conflict (id) do nothing;
