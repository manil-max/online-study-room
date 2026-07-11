-- 0022_social_profile_progression.sql

-- gamification_profiles tablosuna yeni alanlar ekle
ALTER TABLE public.gamification_profiles 
ADD COLUMN IF NOT EXISTS xp integer NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS crown_rank text NOT NULL DEFAULT 'bronze',
ADD COLUMN IF NOT EXISTS selected_badges text[] NOT NULL DEFAULT '{}';

-- Başarılar (Achievements) için kullanıcı ilerleme tablosu
CREATE TABLE IF NOT EXISTS public.user_achievements (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.gamification_profiles(user_id) on delete cascade not null,
  achievement_id text not null,
  tier integer not null default 1,
  progress integer not null default 0,
  unlocked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  UNIQUE(user_id, achievement_id)
);

-- RLS
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

-- Herkes diğerlerinin başarılarını görebilir (Sosyal profil vitrini için)
CREATE POLICY "Anyone can view user achievements" 
  ON public.user_achievements FOR SELECT 
  TO authenticated
  USING (true);

-- Kullanıcılar kendi başarılarını ekleyebilir/güncelleyebilir
CREATE POLICY "Users can insert their own achievements" 
  ON public.user_achievements FOR INSERT 
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own achievements" 
  ON public.user_achievements FOR UPDATE 
  TO authenticated
  USING (auth.uid() = user_id);

-- Updated at trigger
CREATE TRIGGER update_user_achievements_updated_at
BEFORE UPDATE ON public.user_achievements
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- gamification_profiles SELECT politikasını "herkes görebilir" olarak güncelle
DROP POLICY IF EXISTS gamification_profiles_select ON public.gamification_profiles;
CREATE POLICY gamification_profiles_select ON public.gamification_profiles
  FOR SELECT TO authenticated
  USING (true);
