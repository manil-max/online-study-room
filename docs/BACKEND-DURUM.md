# Faz 0A: Canlı Backend Durum Matrisi

> ⚠️ Bu doküman, canlı Supabase veritabanının güncel durumunu denetlemek için WP-38 kapsamında oluşturulmuştur. 
> Ajanların canlı veritabanına doğrudan erişimi olmadığı için, **0020-0023 numaralı migration'ların durumu "bilinmiyor" olarak işaretlenmiştir.** Doğrulama ve uygulama adımları ürün sahibi tarafından (SQL Editor aracılığıyla) yapılmalıdır.

## 1. Migration Matrisi (0001 – 0023)

| No | Migration Adı | Özet | Canlı Durum | Doğrulama Yöntemi |
|---|---|---|---|---|
| 0001 | `initial_schema` | Temel tablolar (profiles, study_groups, vb.) ve RLS | ✅ Uygulandı | `public.profiles` tablosu mevcut. |
| 0002 | `avatars_storage` | Storage bucket ve RLS (avatars) | ✅ Uygulandı | `storage.buckets` içinde `avatars` mevcut. |
| 0003 | `subjects_realtime` | Çalışma konuları ve realtime aktifliği | ✅ Uygulandı | `public.subjects` tablosu mevcut. |
| 0004 | `group_admin` | Grup admin RLS mantığı | ✅ Uygulandı | `is_group_admin` RPC fonksiyonu mevcut. |
| 0005 | `daily_goal` | Profillerde `daily_goal_minutes` alanı | ✅ Uygulandı | `profiles.daily_goal_minutes` kolonu mevcut. |
| 0006 | `group_goal` | Gruplarda `weekly_goal_minutes` alanı | ✅ Uygulandı | `study_groups.weekly_goal_minutes` mevcut. |
| 0007 | `group_daily_totals` | Günlük grup skorları tablosu | ✅ Uygulandı | `public.group_daily_totals` mevcut. |
| 0008 | `membership_lifecycle` | Grup üyeliği ayrılma işlemleri | ✅ Uygulandı | `group_members` üzerinde mantıksal silme. |
| 0009 | `session_visibility` | Oturum görünürlük flag'i | ✅ Uygulandı | `study_sessions` tablosunda visibility. |
| 0010 | `drop_session_group_id` | Oturumlardan group_id bağımlılığının kalkması | ✅ Uygulandı | `study_sessions` tablosunda `group_id` yok. |
| 0011 | `group_daily_totals_v2` | Günlük toplamlar V2 mantığı | ✅ Uygulandı | RLS ve fonksiyon güncellemeleri. |
| 0012 | `group_join_hardening` | Gruba katılma ve invite_code RLS sıkılaştırması | ✅ Uygulandı | `join_group` RPC fonksiyonu güncellenmiş. |
| 0013 | `presence_membership_hardening` | Aktiflik ve üyelik kopmalarını önleme | ✅ Uygulandı | Realtime RLS sıkılaştırmaları. |
| 0014 | `profile_animal` | Profillere kamp ateşi hayvan figürü ataması | ✅ Uygulandı | `profiles.animal` kolonu mevcut. |
| 0015 | `class_chat` | Grup içi metin sohbet tablosu | ✅ Uygulandı | `public.class_messages` mevcut. |
| 0016 | `nudges` | Dürtme (Nudge) etkileşimleri tablosu | ✅ Uygulandı | `public.nudges` mevcut. |
| 0017 | `gamification_profiles` | Oyunlaştırma profilleri tablosu | ✅ Uygulandı | `public.gamification_profiles` mevcut. |
| 0018 | `admin_feedback` | Kullanıcı geri bildirimleri tablosu | ✅ Uygulandı | `public.user_feedback` mevcut. |
| 0019 | `feedback_attachments` | Geri bildirim ek dosyaları (storage) | ✅ Uygulandı | `feedback_attachments` bucket mevcut. |
| 0020 | `super_admin_operations` | Süper-admin logları (admin_audit_logs) | ❓ Bilinmiyor | `public.admin_audit_logs` tablosu mevcut mu? |
| 0021 | `admin_operations` | Duyurular tablosu (announcements) | ❓ Bilinmiyor | `public.announcements` tablosu mevcut mu? |
| 0022 | `social_profile_progression` | xp, crown_rank, user_achievements tablosu | ❓ Bilinmiyor | `public.user_achievements` mevcut mu? (RLS blocker: B7) |
| 0023 | `notification_center` | study_reminders ve announcement_reads | ❓ Bilinmiyor | `public.study_reminders` mevcut mu? |

> ⚠️ **Blocker (B7):** 0022 migration'ı içerisindeki `gamification_profiles` tablosuna uygulanan genel okuma izni (public select) sosyal profili genişletiyor. Gerçek veriler yüklenmeden veya migration canlıya alınmadan önce RLS gözden geçirilmelidir. 

---

## 2. Edge Function Envanteri

Aşağıdaki fonksiyonlar `supabase/functions/` dizininde tanımlanmıştır.

| Fonksiyon Adı | Amaç | Canlı Durum | Doğrulama Yöntemi |
|---|---|---|---|
| `admin-operations` | Süper admin yetkilerini yönetme ve admin RLS işlemlerini aşan görevleri güvenle yürütme | ❓ Bilinmiyor | Supabase Dashboard -> Edge Functions altında `admin-operations` var mı? |
| `admin-user-actions` | Kullanıcı engelleme/silme gibi üst düzey admin aksiyonları | ❓ Bilinmiyor | Supabase Dashboard -> Edge Functions altında `admin-user-actions` var mı? |

---

## 3. Doğrulama Sorguları (SQL Editor)

Kullanıcı, Supabase SQL Editor üzerinden aşağıdaki sorguyu çalıştırarak 0020–0023 migration'larının uygulanıp uygulanmadığını test edebilir:

```sql
-- 0020 Doğrulaması
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public' AND table_name = 'admin_audit_logs'
) as has_0020;

-- 0021 Doğrulaması
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public' AND table_name = 'announcements'
) as has_0021;

-- 0022 Doğrulaması
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public' AND table_name = 'user_achievements'
) as has_0022;

-- 0023 Doğrulaması
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public' AND table_name = 'study_reminders'
) as has_0023;
```

---

## 4. Kullanıcı Aksiyon Listesi (Uygulama Sırası)

Eğer yukarıdaki doğrulama sorgularından `false` dönenler varsa, ürün sahibi aşağıdaki adımları sırayla izlemelidir:

1. **Migration Uygulaması (Supabase SQL Editor):**
   - Eksikse, `supabase/migrations/0020_super_admin_operations.sql` dosyasının içeriğini SQL Editor'e yapıştırıp çalıştırın.
   - Eksikse, `supabase/migrations/0021_admin_operations.sql` dosyasını çalıştırın.
   - Eksikse, `supabase/migrations/0022_social_profile_progression.sql` dosyasını çalıştırın (Blocker uyarısına dikkat!).
   - Eksikse, `supabase/migrations/0023_notification_center.sql` dosyasını çalıştırın.

2. **Edge Functions Deploy:**
   - Supabase CLI kurulu bir ortamda:
     ```bash
     supabase functions deploy admin-operations
     supabase functions deploy admin-user-actions
     ```
   - Komutlarını çalıştırarak fonksiyonları canlıya alın.

3. **İlerlemeyi Kaydet:**
   - Bu adımlar başarıyla tamamlandıktan sonra `progress.md` veya güncel iş takip dokümanınızda bu migration'ların durumunu "✅ Uygulandı" olarak güncelleyin.
