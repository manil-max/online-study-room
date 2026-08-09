-- 0125_monthly_report_consent_and_cron_month.sql
--
-- WP-630. Aylik rapor zincirinde iki ayri kusur; ikisi de sessiz.
--
-- 1) 🔴 RIZA VARSAYILANI ON ISARETLI. `0030` sutunu `default true` ile kurdu.
--    On isaretli onay kutusu KVKK/GDPR'da gecerli riza sayilmaz. Bugune kadar
--    TEK BIR aylik rapor e-postasi gonderilmedi -- `send-report`'u hicbir cron,
--    is akisi veya istemci cagirmiyor ve iki fonksiyon da hicbir yerde deploy
--    edilmiyor (WP-626'da olculdu, `monthly_report_promise_wp626_test.dart`).
--    Dolayisiyla `true` tasiyan hicbir satir BILINCLI bir secimi temsil
--    etmiyor; hepsi varsayilanin kendisi. Kapatmak kimsenin bilerek yaptigi bir
--    secimi silmiyor. Bilerek KAPATMIS kullanicilar zaten `false` ve etkilenmez.
--    Kullaniciya gorunur kayip da yok: gonderim zaten hic baslamadi ve arayuz
--    WP-626'dan beri bunu SOYLUYOR ("yakinda" rozeti + "henuz gonderilmiyor").
--
-- 2) CRON YANLIS AYI ISTIYOR. `0035` isi ayin **2'sinde** kosuyor (`0 6 2 * *`)
--    ve govdede `now() - interval '1 day'` yapiyor; bu ayin 1'ine duser, yani
--    **yeni baslamis ayi** ister -- biten ayi degil. Duzeltme araligi
--    degistirmek DEGIL, govdeyi tamamen KALDIRMAK: `collect-reports` govde
--    verilmediginde bir onceki ayi zaten dogru hesapliyor
--    (`supabase/functions/collect-reports/index.ts:42-48`,
--    `d.setMonth(d.getMonth() - 1)`). Boylece hesap TEK yerde kalir; iki yerde
--    tutulan ayni mantik bu depoda defalarca ayristi.
--
-- Bu goc veri-bagimli TEK ifade tasiyor (asagidaki `update`) ve o ifade bos
-- veritabaninda da anlamlidir? HAYIR -- taze kurulumda `profiles` bostur ve
-- ifade sifir satira dokunur. `0124`'un dersi geregi
-- (`docs/KALITE-PROGRAMI.md` §5.4) satiri ELDE kuran bir pgTAP testi ayni
-- turda geliyor: `supabase/tests/051_monthly_report_consent.test.sql`.
-- Bu tabloda degismezlik guard'i YOK, yani `0124`'teki 42501 sinifi burada
-- olusamaz; test yine de gercek satirla olcer.
--
-- Geri alma: dosyanin sonundaki yorum blogu.

-- ---------------------------------------------------------------------
-- 1) Riza varsayilani
-- ---------------------------------------------------------------------
alter table public.profiles
  alter column monthly_report_opt_in set default false;

update public.profiles
   set monthly_report_opt_in = false
 where monthly_report_opt_in is distinct from false;

comment on column public.profiles.monthly_report_opt_in is
  'WP-630: aylik rapor e-postasi icin ACIK riza. Varsayilan FALSE -- on '
  'isaretli onay kutusu gecerli riza degildir. Gonderim henuz hic '
  'baslamadi; ozellik acildiginda kullanici bunu kendisi acar.';

-- ---------------------------------------------------------------------
-- 2) Aylik rapor toplayicisinin cron govdesi
-- ---------------------------------------------------------------------
-- Govde `0035`teki ile birebir aynidir; TEK fark `body :=` blogunun
-- kaldirilmasidir. Aralik (`0 6 2 * *`) da bilerek aynidir: ayin 2'sinde
-- kosmak dogrudur, yanlis olan hangi ayin istendigiydi.
do $wp630$
begin
  if not exists (select 1 from pg_namespace where nspname = 'cron') then
    raise notice 'pg_cron yok -- monthly-report-collector guncellenmedi.';
    return;
  end if;

  begin
    perform cron.unschedule('monthly-report-collector');
  exception
    when others then
      raise notice 'unschedule monthly-report-collector: %', sqlerrm;
  end;

  perform cron.schedule(
    'monthly-report-collector',
    '0 6 2 * *',
    $cron$
      select net.http_post(
        url := rtrim(
          coalesce(
            nullif(current_setting('app.settings.supabase_url', true), ''),
            nullif(current_setting('app.settings.functions_base_url', true), '')
          ),
          '/'
        ) || '/functions/v1/collect-reports',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || coalesce(
            nullif(current_setting('app.settings.service_role_key', true), ''),
            ''
          ),
          'x-cron-secret', coalesce(
            nullif(current_setting('app.settings.cron_secret', true), ''),
            ''
          )
        )
      );
    $cron$
  );
end $wp630$;

-- ---------------------------------------------------------------------
-- Geri alma (elle):
--   alter table public.profiles
--     alter column monthly_report_opt_in set default true;
--   -- Satir degerleri GERI ALINMAZ: hangi satirin bilerek `true` oldugu
--   -- bilinmiyor ve toplu geri acmak yeniden on-isaretli riza olurdu.
--   -- Cron icin `0035`teki bloku aynen yeniden uygula.
-- ---------------------------------------------------------------------
