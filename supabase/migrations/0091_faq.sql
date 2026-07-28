-- 0091_faq.sql
-- WP-388: Giriş öncesi okunabilen, yayın kontrollü SSS ve oturumlu soru gönderimi.

create table if not exists public.faq_entries (
  id uuid primary key default gen_random_uuid(),
  locale text not null check (locale in ('tr', 'en')),
  question text not null check (char_length(trim(question)) between 3 and 240),
  answer text not null check (char_length(trim(answer)) between 3 and 4000),
  sort_order integer not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists faq_entries_published_locale_order_idx
  on public.faq_entries (locale, sort_order)
  where is_published;

alter table public.faq_entries enable row level security;

drop policy if exists faq_entries_anon_read_published on public.faq_entries;
create policy faq_entries_anon_read_published
  on public.faq_entries for select to anon, authenticated
  using (is_published = true);

drop policy if exists faq_entries_admin_write on public.faq_entries;
create policy faq_entries_admin_write
  on public.faq_entries for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

grant select on public.faq_entries to anon, authenticated;

create or replace function public.submit_faq_question(p_question text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_question text := trim(coalesce(p_question, ''));
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'session_required';
  end if;
  if char_length(v_question) < 3 or char_length(v_question) > 1200 then
    raise exception 'invalid_question';
  end if;

  insert into public.feedback_tickets (
    user_id, kind, ticket_type, subject, message, status
  ) values (
    auth.uid(), 'feedback', 'question', left(v_question, 80), v_question, 'open'
  ) returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.submit_faq_question(text) from public;
grant execute on function public.submit_faq_question(text) to authenticated;

insert into public.faq_entries (locale, question, answer, sort_order, is_published)
values
  ('tr', 'Ana ekrana widget nasıl eklenir?', 'Telefonunun widget ekleme ekranından Odak Kampı widgetını seç. Bildirim izni ve pil optimizasyonu kapalıysa widget güncel kalmayabilir.', 10, true),
  ('tr', 'Bildirimleri nereden kontrol ederim?', 'Ayarlar > Bildirimler bölümünden izinleri ve uygulama içi duyuruları kontrol edebilirsin.', 20, true),
  ('tr', 'Pil optimizasyonu neden önemli?', 'Bazı telefonlar arka plandaki uygulamaları durdurur. Odak Kampı için pil optimizasyonunu kapatmak zaman ve bildirim güncellemelerini iyileştirir.', 30, true),
  ('tr', 'Birden fazla cihazda ne olur?', 'Aynı hesaptaki cihazlar sunucudaki çalışma durumunu eşitler. Ağ gecikmesi sırasında son karar sunucudaki durumdur.', 40, true),
  ('tr', 'Birincil grup nedir?', 'Birincil grup günlük hedef, seri ve bazı istatistik katkılarının bağlandığı gruptur. Ayarlardan değiştirebilirsin.', 50, true),
  ('tr', 'Dürtme nedir?', 'Dürtme, grup arkadaşına çalışmayı hatırlatan nazik bir bildirimdir. Bildirim ayarlarından yönetilebilir.', 60, true),
  ('tr', 'Seri kuralları nasıl çalışır?', 'Günlük hedefini gün bitmeden tamamladığında seri ilerler. Gün sınırı grubunun zaman dilimine göre hesaplanır.', 70, true),
  ('tr', 'XP nasıl kazanılır?', 'Doğrulanmış çalışma oturumları ve uygulamadaki kurallar XP kazandırır; XP sunucu tarafından hesaplanır.', 80, true),
  ('tr', 'Başarımları nasıl kazanırım?', 'Başarımlar çalışma düzenin ve hedeflerinle ilgili koşulları tamamladığında açılır. Ayrıntılar Başarımlar ekranındadır.', 90, true),
  ('tr', 'Gün ne zaman biter?', 'Gün, grubunun veya hesabının etkin zaman diliminde gece yarısında biter.', 100, true),
  ('tr', 'İnternetim yokken ne olur?', 'Uygulama son bilinen bilgileri gösterebilir. Süre ve grup verilerinin güvenli eşitlenmesi için tekrar çevrimiçi olman gerekir.', 110, true),
  ('tr', 'Elle eklenen süre sayılır mı?', 'Elle eklenen kayıtların hangi hedef ve ödüllere katkı verdiği ilgili akışta gösterilir; doğrulanan zaman sunucuda hesaplanır.', 120, true),
  ('en', 'How do I add a home-screen widget?', 'Open your phone widget picker and select the Focus Camp widget. Notification permission and battery optimisation can affect updates.', 10, true),
  ('en', 'Where can I manage notifications?', 'Open Settings > Notifications to review permissions and in-app announcements.', 20, true),
  ('en', 'Why does battery optimisation matter?', 'Some phones stop background apps. Excluding Focus Camp from battery optimisation helps time and notification updates.', 30, true),
  ('en', 'What happens on multiple devices?', 'Devices on the same account sync the server-side study state. During a network delay, the server state is authoritative.', 40, true),
  ('en', 'What is a primary group?', 'Your primary group is used for daily goals, streaks and some statistic contributions. You can change it in Settings.', 50, true),
  ('en', 'What is a nudge?', 'A nudge is a gentle reminder for a group mate. You can manage it in notification settings.', 60, true),
  ('en', 'How do streak rules work?', 'Your streak progresses when you complete the daily goal before the day ends in the group time zone.', 70, true),
  ('en', 'How do I earn XP?', 'Verified study sessions and in-app rules award XP; the server calculates XP.', 80, true),
  ('en', 'How do I earn achievements?', 'Achievements unlock when you meet study and goal conditions. See the Achievements screen for details.', 90, true),
  ('en', 'When does the day end?', 'The day ends at midnight in your active group or account time zone.', 100, true),
  ('en', 'What happens when I am offline?', 'The app can show its last known information. Reconnect to safely sync time and group data.', 110, true),
  ('en', 'Does manually added time count?', 'The relevant flow explains which goals and rewards a manual record affects; verified time is calculated on the server.', 120, true)
on conflict do nothing;
