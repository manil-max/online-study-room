-- 0127_backfill_reconcile_existing_gamification.sql
--
-- WP-634 devami. `0126` bundan SONRAKI her silmeyi otomatik duzeltir; bu goc
-- GECMISI temizler.
--
-- Neden ayri bir goc: `0126` tetikleyici kurar, tetikleyici de yalniz silme
-- ANINDA atesler. Kaydini daha once silmis kullanicida tetikleyecek bir sey
-- yoktur -- bu olayin ta kendisi oyle basladi (sahibin kardesi sahte oturumu
-- sildi, kazanim yerinde kaldi). Yani mekanizmayi kurmak yetmez, bir kez de
-- gecmise uygulamak gerekir.
--
-- 🔴 HEDEF SECIMI. Belirli bir kullaniciyi adiyla/e-postasiyla yazmiyoruz.
-- Iki sebep: (1) depo herkese aciktir, kimsenin e-postasi buraya yazilmaz;
-- (2) ayni durum baskasinda da olabilir ve hedefli bir goc onu KACIRIRDI.
-- Kural kisiye degil DURUMA bakar: "defterindeki kazanim gercek oturumlariyla
-- uyusmayan herkes".
--
-- Uzlastirmanin kendisi `0126`da tanimli ve `supabase/tests/052` ile
-- kanitlanmistir (12 iddia, gercek Postgres): kapsam disi basarimlara,
-- kumulatif metriklere ve baska kullanicilarin defterine DOKUNMAZ.
--
-- Geri alma (Rollback): YOKTUR ve olamaz -- dusen satirlar zaten hak
-- edilmemisti. Yanlislikla dusen bir satir olsaydi bu bir kusur olurdu, geri
-- alinacak bir karar degil.

do $wp634$
declare
  v_user uuid;
  v_count integer := 0;
  v_drift integer;
begin
  -- Yalniz gamification profili OLAN kullanicilar; digerlerinde uzlastiracak
  -- bir sey yok ve `_achievement_metrics` bosuna kosardi (o fonksiyon
  -- projeksiyon da YAZAR, bedava degildir).
  for v_user in
    select g.user_id
      from public.gamification_profiles g
     where public._account_still_exists(g.user_id)
     order by g.user_id
  loop
    perform public.reconcile_user_gamification(v_user);
    v_count := v_count + 1;
  end loop;

  raise notice 'WP-634 backfill: % kullanici uzlastirildi', v_count;

  -- 🔴 GOC KENDINI DOGRULAR. Uzlastirmadan sonra her profilin bakiyesi kendi
  -- defterinin toplamina esit olmak ZORUNDA. Esit degilse sessizce gecmeyiz;
  -- islem geri sarilir ve neden bilinerek bakilir. "Yesil ama olcmemis" goc
  -- bu depoda bir kez uretime ulasti (`0124`, ayni gece); bir daha olmasin.
  select count(*) into v_drift
    from public.gamification_profiles g
   where public._account_still_exists(g.user_id)
     and g.xp is distinct from (
       select coalesce(sum(l.xp_amount), 0)::integer
         from public.xp_ledger l where l.user_id = g.user_id
     );

  if v_drift > 0 then
    raise exception
      'WP-634 backfill dogrulamasi BASARISIZ: % profilin bakiyesi kendi '
      'defteriyle uyusmuyor', v_drift;
  end if;
end $wp634$;
