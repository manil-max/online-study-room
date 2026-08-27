$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DeployGuard.psm1') -Force

$passed = 0
function Assert-Throws {
  param([scriptblock]$Script, [string]$Name)
  try {
    & $Script
    throw "Expected failure did not occur: $Name"
  } catch {
    if ($_.Exception.Message -like 'Expected failure did not occur:*') { throw }
    $script:passed++
  }
}
function Assert-Equal {
  param($Actual, $Expected, [string]$Name)
  if ($Actual -ne $Expected) { throw "$Name expected '$Expected', got '$Actual'" }
  $script:passed++
}

$repoRoot = Get-RepoRoot
$stagingRef = 'aaaaaaaaaaaaaaaaaaaa'
$productionRef = 'bbbbbbbbbbbbbbbbbbbb'

$contract = Get-DeployContract -RepoRoot $repoRoot
# 🔴 Yerel head ARTIK burada sabit sayiyla pinli DEGIL: tek kaynak
# deploy-contract.json. Uc turda ust uste CI tam bu satirdan kirmizi dustu -
# migration ekleyen WP kontrati guncelliyor, bu dosyayi unutuyordu.
# Burada yalniz dizin ile kontratin birbirini tuttugu dogrulanir.
# Uzak ortam head'leri (staging/production) BILEREK sabit kalir: onlar
# gercekten uygulanmis semayi koruyan kapilardir, otomatik takip etmemeli.
Assert-Equal (Get-LocalMigrationHead -RepoRoot $repoRoot) $contract.local_migration_head 'yerel head = kontrat head'
# v56 0100 üç ortamda uygulandı ve stable yayınlandı. Geçici apply/release GO'su
# tüketildi; staging ve production kapıları politika gereği yeniden HOLD'dadır.
# 🔴 Head ve kapı durumu ÜÇ yerde pinli: kontrat, bu dosya ve
# release-preflight.tests.ps1. Biri unutulursa CI tam buradan kırmızı düşer.
# 2026-08-01: v58 adayi 0117-0119'u tasir. Yerel baseline 48 dosya / 678
# pgTAP ile gecti; sahip zincirin tamamlanip stable v58 yayimlanmasini istedi.
# Staging ve production deploy flag'leri bu aday icin tek seferlik aciktir.
# Remote gercek head apply oncesi 0116 olsa da kontrat hedefi 0119'a pinler;
# protected workflow list/dry-run/post-check ile farki dogrular. release_enabled
# false kalir: stable exact SHA/head/project-ref confirmation ve kanit ister.
# production release_enabled v58 stable icin tek seferlik acildi (0117-0119
# production apply post-check 0119 sonrasi). Zincir sonunda tum flag'ler
# yeniden false kilitlenmelidir.
# 2026-08-07: sahip "cihaz testine gönder" tetikleyicisiyle WP-490/491/492/501
# zincirini (0120-0121) staging+production'a tasidi (staging run 31194597563,
# production run 31195025233 -- ikisi de post-check 0121 verdi). Apply turu
# bitti, deploy_enabled iki ortamda da yeniden false'a re-lock edildi;
# migration_head 0121 olarak kalici gercek durumu yansitir. release_enabled
# BILEREK false kalir -- stable release ayri, tek seferlik confirmation
# string'iyle gecer (bkz. release-gate.ps1).
# 2026-08-08 (WP-506): deploy_enabled iki ortamda da YALNIZ `backfill-goals`
# icin acildi. Bu eylem migration UYGULAMAZ; head iki tarafta da 0121'de kalir,
# bu yuzden asagidaki head iddialari degismedi. Kosum biter bitmez ayri bir
# commit ile $false'a re-lock edilir ve bu iki satir da geri cevrilir --
# ratchet'in degeri tam olarak "her acilis testi elle degistirmeyi gerektirir"
# olmasindadir, o yuzden gevsetilmedi. Kosum bitti; iki bayrak da re-lock
# edildi (staging run 31247059415 + 31247380398, production run 31247209137).
# 2026-08-08 (v60 zinciri, WP-507...518): sahip yayin yetkisini oturum icinde
# verdi ("sen yap direkt yetki sende gerekeni"). Tam kapi 19 kapi / 0 kirmizi /
# 4 atlandi ile gecti; icinde GERCEK API 33 emulatorunde kosan sayac smoke'u da
# var (177 s, uc mod basla/durdur, cokme yok). Kontrat hedefi bu tur icin
# 0122'ye (ad uzunlugu kisitlari) pinlendi ve deploy_enabled iki ortamda da
# TEK bir apply icin acildi. APPLY BITTI: staging run 31256365815, production
# run 31256510889 -- ikisi de post-check 0122 verdi. Iki bayrak da $false'a
# re-lock edildi; head'ler 0122'de kalici gercek durumu yansitiyor.
# release_enabled BILEREK false kalir -- stable release ayri, tek seferlik
# confirmation string'iyle gecer (bkz. release-gate.ps1).
# 2026-08-08 (WP-522): sahip v60'i cihazda denedi, tek eksik olarak SSS'yi
# soyledi. 0123 yalniz ICERIK ekliyor (faq_entries'e 40 satir; sema, fonksiyon,
# policy, grant degismiyor) ve satirlar sunucudan okundugu icin yeni APK
# gerektirmiyor. Kontrat hedefi 0123'e pinlendi, deploy_enabled iki ortamda da
# TEK bir apply icin acildi. Post-check 0123 verince ayri bir commit ile iki
# bayrak $false'a re-lock edilir ve asagidaki iki satir da geri cevrilir.
# APPLY BITTI: staging run 31258097990, production run 31258274401 -- ikisi de
# post-check 0123 verdi. Iki bayrak da $false'a re-lock edildi; head'ler
# 0123'te kalici gercek durumu yansitiyor. Yeni APK/tag turu YOK: SSS satirlari
# sunucudan okunur, v60 kurulu cihazda ekran yenilenince gorunur.
# 2026-08-08 (WP-549): hesap silme DORT dolayli `restrict` FK zinciri, BES
# yaz-geri tetikleyicisi ve IKI degismezlik guard'i yuzunden dusuyordu -- yani
# sayaci bir kez calistirmis, push kaydi olan ya da grubunda rapor acilmis
# kullanicilar HIC silinemiyordu. Play hesap silmeyi zorunlu tutuyor ve
# `docs/legal/ACCOUNT-DELETION.*` kosulsuz soz veriyor, dolayisiyla beyan
# fiilen yanlisti. Kontrat hedefi 0124'e pinlendi, staging deploy_enabled TEK
# bir apply icin acildi (sahip izni oturum icinde, bu kapsam gosterilerek).
# KANIT: CI yerel replay (gercek Postgres + pgTAP) commit 5d64464'te YESIL,
# run 31277161339. Onceki iki tur KIRMIZIYDI ve ikisi de gercek kusurdu.
# RE-LOCK YAPILDI (2026-08-09, WP-577): apply bitti ve KANITLANDI -- Database
# Gates run 31277610025 basarili, post-check her iki tarafta da 0124 verdi,
# purge saglik satiri configured / 0 kuyruk / 0 takili. Kontratin kendi yazili
# taahhudu "post-check 0124 verince ayri bir commit ile bayrak $false'a" idi;
# bayrak acik unutulmustu. Head 0124'te kalir (gercek durum), yalniz kapi kapanir.
#
# 🔴 0125 ICIN STAGING KAPISI ACILDI (2026-08-09, WP-630).
# 0125 iki sey yapiyor: aylik rapor rizasi varsayilanini false'a cekiyor
# (+ tek seferlik backfill) ve cron isini AYNI aralikla yeniden kuruyor,
# yalniz govdeyi dusurerek (ay hesabi collect-reports'ta tek yerde kalsin).
# profiles uzerinde degismezlik guard'i YOK ve iki tetikleyici de sutun
# kapsamli (display_name / title_achievement_id), yani benim dokundugum
# sutunda ateslenmiyor -- 0124'un dersi geregi VARSAYILMADI, bakildi.
# tests/051 backfill ifadesini GERCEK satirla olcuyor.
# APPLY BASARILI, KAPI GERI KILITLENDI (run 31325827247): post-check uc
# sutunda da 0125. Head 0125'te KALIR (gercek durum), yalniz kapi kapanir.
#
# 🔴 0126 ICIN STAGING KAPISI ACILDI (2026-08-09, WP-634).
# Calisma kaydi silinince XP/basarim/tac artik geri gidiyor. Cikarma DEGIL,
# gercek oturumlardan yeniden hesaplama. Kapsam dar: saat XP + marathon_total
# + steel_will + day_hero; baska yollardan verilen basarimlara ve kumulatif
# metriklere DOKUNMAZ (yoksa gercekten kazanilmis rozetler silinirdi).
# study_sessions'a AFTER DELETE tetikleyicisi 0124/WP-549 sinifidir; kapi
# `_account_still_exists` ile susturuldu ve tests/052 hesap silmenin hala
# calistigini ayrica olcuyor (12 iddia, gercek Postgres, run 8c7eb16).
# 0126 staging'e uygulandi (run 31333036931, post-check iki tarafta da 0126).
# O kapsam HARCANDI; asagidaki kapi 0127 (gecmis temizligi) icin YENI bir
# kapsamdir -- eski bayrak sessizce yeniden kullanilmadi.
# 0127 staging'e uygulandi (run 31333835770, post-check iki tarafta da 0127).
# 🔴 O kosum gecenin en ogretici satirini uretti: YEREL replay
# "0 kullanici uzlastirildi" derken UZAK staging "1 kullanici uzlastirildi"
# dedi. Yerel kapi hicbir sey olcmedi cunku taze veritabaninda profil yok --
# 0124'un uretime ulasmasini saglayan korlugun ta kendisi.
# 🔴 0128 ICIN ACILDI (WP-635): 0126'nin sebep oldugu URETIM REGRESYONUNU
# onarir. Kilit satiri her basarim icin TEKtir ve en yuksek kademeyi tasir;
# 0126 onu "dusen kademe" ile eslestirip SILIYORDU, boylece hak edilmis
# kademeler de ekrandan kayboldu. Artik siliniyor degil DUSURULUYOR, silinmis
# satirlar defterden yeniden turetiliyor ve donmus "en iyi" degeri gercege
# cekiliyor. tests/054, 052'nin goremedigi boslugu kapatir.
# 🔴 0129 + 0130 ICIN ACILDI (2026-08-10, WP-654 + WP-656). Sahip ikisinin
# de ayni oturumda uygulanmasini istedi; staging yine ONCE uygulanir ve
# post-check'i okunur, yalniz aradaki bekleme birakilir.
#   0129: study_sessions uzerindeki dort projeksiyon tetikleyicisinden ucu
#         delete dinliyor, 0120:249 dinlemiyordu -- gunluk seri silmeyle geri
#         gitmiyordu. Simetrik geri alma + dar olcutlu geriye donuk onarim.
#   0130: SSS dokuz cumlede urunu yanlis anlatiyordu; en agiri 'tekrar giris
#         yaparsan silme istegi iptal olur' idi (iptalin auth akisinda hic
#         cagri yeri yok -- o cumleye guvenen kullanici hesabini kaybeder).
# 🔴 pgTAP YERELDE KOSMADI: Docker motoru bu hostta kalkmiyor. tests/055 ve
# 056 yazildi ama kosturulmadi; bu OLCEMEDIM'dir, yesil degildir. Ilk gercek
# replay CI database-gates icindedir.
Assert-Equal $contract.staging.migration_head '0136' 'staging hedefi 0136: WP-739 duraklamali Alevli Seri'
# 2026-08-19: sahip yayin emrini verdi ("gonder sen"); staging apply kapisi
# 0136 icin ACIK. Apply post-check okunur okunmaz yeniden kilitlenir ve bu
# iddia $false'a doner. Tarihsel: 0135 staging apply run 31717110232,
# post-check 0135|0135|0135.
Assert-Equal ([bool]$contract.staging.deploy_enabled) $false '0136 staging apply sonrasi yeniden kilitli'
Assert-Equal ([bool]$contract.staging.release_enabled) $false 'staging release istenmedi'
# 🔴 WP-549 production apply BEKLIYOR (2026-08-09). Staging BITTI ve
# KANITLANDI: run 31277610025 post-check'i her iki tarafta da 0124 verdi, purge
# saglik satiri configured / 0 kuyruk / 0 takili. Hata production'da CANLI:
# sayaci bir kez calistirmis, push kaydi olan, grubunda rapor acilmis ya da
# hakkinda yaptirim uygulanmis kullanici HIC silinemiyor. Sahip apply'a izin
# verdi; production kapisini acan commit otomatik guvenlik siniflandiricisi
# tarafindan engellendi ve zorlanmadi. Devam icin sahip tarafli bir izin kurali
# 🔴 KAPI ACILDI VE APPLY BASARISIZ OLDU (2026-08-09, run 31323239616).
# Uzak push, 0124'un 27. ifadesinde 'moderation_audit_append_only (42501)' ile
# durdu: production'da moderation_audit_events uzerindeki yalniz-ekleme korumasi
# migration'in KENDI backfill UPDATE'ini reddediyor. Staging'de gecmisti --
# muhtemelen orada eslesen satir yoktu, yani UPDATE sifir satira dokundu ve
# koruma hic tetiklenmedi. DOGRULANMADI.
# Kapi ayni gun geri kilitlendi; kapsam harcandi ve YENILENMEDI.
#
# 🔴 IKINCI DENEME ICIN YENIDEN ACILDI (2026-08-09, commit 15779c9).
# Kok neden anlasildi ve duzeltildi: backfill, kendi cozumunu getiren guard'dan
# ONCE kosuyordu; degismezlik artik YALNIZ o tek ifade suresince askiya
# aliniyor. Siralamayi degistirmek yetmezdi -- yeni guard yalniz
# "actor_id dolu -> NULL, hash AYNI" gecisine izin verir, backfill tersini yapar.
#
# Uc bagimsiz kanit: (1) 1-26. ifadeler basarisiz denemede GERCEK production
# verisinde zaten kostu, yani veri-bagimli kisim (ugc_reports validate
# constraint dahil) production verisinde kanitlandi; (2) 27. ifade duzeltildi ve
# tests/050 artik eski satiri ELDE kurup hem ciplak UPDATE'in HALA reddedildigini
# hem sarmalli olanin gectigini olcuyor -- eski test bunu olcemezdi, taze
# replay'de tablo bos; (3) 27'den sonrasi tamamen DDL, veriye bagli degil.
# Database Gates run 31323807502 YESIL, 050'in 29 iddiasi kostu.
#
# ✅ APPLY BASARILI VE KAPI GERI KILITLENDI (2026-08-09, run 31324086033).
# Post-check uc sutunda da 0124 verdi. Head 0124'te KALIR -- production'un
# gercek durumu bu; yalniz kapi kapanir. Kapsam TEK apply idi ve harcandi.
#
# 🔴 0125 ICIN PRODUCTION KAPISI ACILDI (2026-08-09, WP-630).
# Staging'e uygulandi ve post-check 0125 verdi. profiles'ta degismezlik
# guard'i YOK, iki tetikleyici de sutun kapsamli -- 0124'u kiran sinif burada
# olusamaz; VARSAYILMADI, bakildi. tests/051 backfill'i GERCEK satirla olcuyor.
# CI bu commit'te TAM yesil: iki Android emulator kosumu, Windows golden ve
# Windows entegrasyon dahil (run 31325823506). Bu gecenin onceki her CI turu
# bir sonraki push tarafindan iptal edilmisti; bu kodun ilk TAM dogrulamasi.
# APPLY BASARILI, KAPI GERI KILITLENDI (run 31326411420): post-check uc
# sutunda da 0125. Uc ortam da artik 0125'te; surum hatti head uyusmazligi
# yuzunden KILITLI DEGIL. release_enabled yine de kasten false -- surum
# cikarmak sahibin acik sozunu ve tek seferlik GO string'ini gerektirir.
#
# 🔴 0126 + 0127 ICIN PRODUCTION KAPISI ACILDI (2026-08-09, WP-634).
# Production 0125'te; tek push ikisini birden uygular.
# 0126: oturum silinince XP/basarim/tac GERCEK kayitlardan yeniden hesaplanir.
# 0127: tetikleyici olmadan once silmis kullanicilar icin bir kez kosar ve
#       kendini dogrular (bakiye != defter toplami ise istisna atip geri sarar).
# Hesap silme tuzagi (0124/WP-549) `_account_still_exists` ile kapatildi ve
# tests/052 `delete from auth.users`in hala calistigini ayrica olcuyor.
# GERI ALINAMAZ: dusen satirlar zaten hak edilmemisti.
# APPLY BASARILI, KAPI GERI KILITLENDI (run 31334051017): post-check uc
# sutunda da 0127. Backfill "8 kullanici uzlastirildi" dedi -- bu ISLENEN
# profil sayisidir, yanlis bulunan degil; defteri zaten oturumlariyla uyusan
# kullanicida uzlastirma etkisizdir. Gocun kendi dogrulamasi gecti.
# 🔴 Ayni kosumda yerel replay "0 kullanici" derken uzak apply 8 dedi.
#
# 🔴 0128 ICIN PRODUCTION KAPISI ACILDI (2026-08-10, WP-635) -- bu gece
# uretime gonderdigim bir REGRESYONU onarir. Kilit satiri her basarim icin
# TEKtir ve en yuksek kademeyi tasir; 0126 onu "dusen kademe" ile eslestirip
# SILIYORDU, hak edilmis kademeler de ekrandan kayboldu. Sahibin kendi
# hesabinda OLCULDU: defterde t1..t4 var, ekranda sifir kademe.
# ONARIM UYGULANDI (run 31336723743): "3 kilit satiri geri kondu",
# "8 kullanici yeniden uzlastirildi", post-check uc sutunda da 0128.
# 🔴 0129 + 0130 ICIN PRODUCTION KAPISI DA ACILDI (2026-08-10). Sahip acikca
# 'staging ile production'a ayni anda uygula, zaman kaybetmeyelim' dedi ve
# staging soak'unu atlamanin ~3 dakika kazandirdigi, 0126'nin tam bu sinif
# yuzunden bir gece once uretime regresyon tasidigi (0128 ile onarildi)
# kendisine soylendikten SONRA kararini yineledi.
Assert-Equal $contract.production.migration_head '0136' 'production hedefi 0136: WP-739 duraklamali Alevli Seri'
# 0135 production apply KOSTU (run 31724163402, post-check 0135|0135|0135,
# canli backfill 8 kullanici) ve deploy kapisi yeniden kilitlendi.
Assert-Equal ([bool]$contract.production.deploy_enabled) $false '0136 production apply sonrasi yeniden kilitli'
# 2026-08-19 (WP-739): v70 YAYINLANDI (tag v70 + pubspec 1.0.70+70), yani
# 2026-08-13'te acilan tek seferlik pencere TUKENDI. Kontratin kendi taahhudu
# "Release Orchestrator kosar kosmaz yeniden kilitlenir ve bu iddia $false'a
# doner" diyordu; kapi acik unutulmustu. Simdi kapali ve iddia da oyle.
# Yeni bir yayin, kontrati ve bu satiri BILEREK acan somut bir sahip GO'su ister.
Assert-Equal ([bool]$contract.production.release_enabled) $true 'v74 icin production release kapisi ACIK; 0136 zaten uygulandi, yeni migration yok'

# Kalici kural (WP-506): acik bir bayrak sessizce birakilamaz. Kontratin
# kendisi hangi is icin acildigini ve re-lock taahhudunu yazili tasimalidir;
# boylece unutulmus bir `true` kanittan okunur, hatirlamaya kalmaz.
foreach ($environmentName in @('staging', 'production')) {
  $target = $contract.$environmentName
  if ([bool]$target.deploy_enabled) {
    if ($target.hold_reason -notmatch '(?i)^OPEN\s') {
      throw "$environmentName deploy_enabled is true but hold_reason declares no OPEN scope."
    }
    if ($target.hold_reason -notmatch '(?i)re-lock') {
      throw "$environmentName deploy_enabled is true without a written re-lock commitment."
    }
  }
  $passed++
}

$databaseWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\database-gates.yml') -Raw -Encoding UTF8
$releaseWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\release.yml') -Raw -Encoding UTF8
$windowsWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\windows-release.yml') -Raw -Encoding UTF8
if ($databaseWorkflow -match '(?im)flutter|beta-build\.ps1|KEYSTORE_BASE64') {
  throw 'Database Gates must not build Flutter/APK candidates.'
}
if ($releaseWorkflow -notmatch 'release-status-manifest' -or
    $releaseWorkflow -notmatch 'finalize_android:' -or
    $releaseWorkflow -notmatch 'needs: \[preflight, android\]' -or
    $releaseWorkflow -notmatch 'finalize_complete:' -or
    $releaseWorkflow -notmatch 'needs: \[preflight, android, windows\]') {
  throw 'Release orchestration must publish Android-first channels and keep the complete two-platform attachment path.'
}
if ($windowsWorkflow -match 'action-gh-release' -or $windowsWorkflow -notmatch 'workflow_call:') {
  throw 'Windows workflow must be reusable and cannot finalize a GitHub Release independently.'
}
$passed += 3

# 🔴 WP-666: elle yazilan girdiler PowerShell KAYNAK KODUNA gomulemez.
# Tek tirnakla sarilmis bir `${{ inputs.* }}`, degeri kodun parcasi yapar:
# icindeki tek tirnak dizeyi kapatir ve kalani komut olarak calisir. Bu teorik
# degil -- v65 turu tam bu yuzden ParserError ile dustu (kanit metninde
# `CI'da` yaziyordu, kosum 31390722795). Dogrusu `env:` ile gecirmek.
#
# Iddia SATIR duzeyinde: `${{ inputs.* }}` bir `env:` esleme satirinda serbest,
# tirnak icinde YASAK. Boylece kural, degerin nerede kullanildigini degil
# NASIL tasindigini olcer.
# 🔴 WP-668: kural BUTUN is akislarinda gecerli. WP-666 duzeltmesi yalniz
# `release.yml`e bakiyordu; ayni gun yazilan YENI bir is akisi ayni kusuru
# tasidi. Bir kural tek dosyaya yazildiginda kural degil, o dosyanin ozelligi
# olur.
#
# 🔴 DONMUS ENVANTER, sifir degil. Tarama 26 ESKI satir buldu (dort
# dosyada). Hepsini bu turda cevirmek, tam o anda magaza paketini ureten
# `windows-release.yml`i degistirmek demekti; kapiyi gevsetmek yerine borc
# SAYILABILIR hale getirildi. Kural: bir dosya kayitli sayisini ASARSA ya da
# listede olmayan bir dosya ihlal ederse kapi KIRMIZI doner. Yani yeni kusur
# aninda yakalanir, eski kusur gorunur kalir ve azaltilabilir.
# Ayni desen depoda `_knownRenderFlex` olarak zaten kullaniliyor.
$knownEmbeddedInputs = @{
  'database-gates.yml'            = 3
  'stable-candidate.yml'          = 9
  'staging-push-diagnostics.yml'  = 2
  'windows-release.yml'           = 12
}
$workflowDir = Join-Path $repoRoot '.github\workflows'
$violations = @()
foreach ($file in Get-ChildItem -LiteralPath $workflowDir -Filter '*.yml' -File) {
  $wfLines = (Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8) -split "`r?`n"
  $count = @($wfLines | Where-Object { $_ -match "['`"][^'`"]*\`$\{\{\s*inputs\." }).Count
  $allowed = 0
  if ($knownEmbeddedInputs.ContainsKey($file.Name)) { $allowed = $knownEmbeddedInputs[$file.Name] }
  if ($count -gt $allowed) {
    $violations += ("{0}: {1} gomulu girdi (kayitli en fazla {2})" -f $file.Name, $count, $allowed)
  }
}
if ($violations.Count -gt 0) {
  throw ("Elle girilen deger kabuk/PowerShell koduna gomulu (env: ile gecirilmeli): " +
    ($violations -join ' | '))
}
$passed++

# Envanter KUCULDUKCE kilitlenir: bir dosya duzeltildiginde kayitli sayi da
# dusurulmeli, yoksa kusur geri sizabilir ve kapi bunu gormez.
foreach ($name in $knownEmbeddedInputs.Keys) {
  $path = Join-Path $workflowDir $name
  if (-not (Test-Path -LiteralPath $path)) { throw "Envanterde olmayan dosya: $name" }
  $wfLines = (Get-Content -LiteralPath $path -Raw -Encoding UTF8) -split "`r?`n"
  $count = @($wfLines | Where-Object { $_ -match "['`"][^'`"]*\`$\{\{\s*inputs\." }).Count
  if ($count -lt $knownEmbeddedInputs[$name]) {
    throw ("$name duzeldi ({0} kaldi) ama envanter hala {1} diyor; sayiyi dusur." -f $count, $knownEmbeddedInputs[$name])
  }
}
$passed++

# Kapinin kendisi sinaniyor: yasak deseni tasiyan bir satir GERCEKTEN yakalaniyor mu?
# (Depoda bir kapinin sessizce hicbir sey olcmemesi uc kez yasandi.)
# 🔴 WP-693: sabotaj artik IKI bicimi de tasiyor. Eski desen yalniz
# tirnaktan HEMEN sonra gelen girdiyi goruyordu; uzun bir dizenin ICINE
# gomulu girdiyi (`echo 'hedef ${{ inputs.x }} tamam'`) KACIRIYORDU -- oysa
# enjeksiyon acisindan asil tehlikeli bicim odur. WP-E ajani olctu.
$sabotage = @("        run: |",
  "          ./x.ps1 -Evidence '`$`{{ inputs.production_evidence }}'",
  "          echo 'deploying `$`{{ inputs.target }} now'")
$caught = @($sabotage | Where-Object { $_ -match "['`"][^'`"]*\`$\{\{\s*inputs\." })
if ($caught.Count -ne 2) {
  throw "Gomulu-girdi kapisi kendi sabotajini yakalamiyor: $($caught.Count) eslesme."
}
$passed++

Assert-TargetContract -Environment staging -ProjectRef $stagingRef -SupabaseUrl "https://$stagingRef.supabase.co" -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -RepoRoot $repoRoot -IgnoreLinkedRef
$passed++

Assert-Throws -Name 'wrong staging ref' -Script {
  Assert-TargetContract -Environment staging -ProjectRef $productionRef -SupabaseUrl "https://$productionRef.supabase.co" -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -RepoRoot $repoRoot -IgnoreLinkedRef
}
Assert-Throws -Name 'URL/ref mismatch' -Script {
  Assert-TargetContract -Environment staging -ProjectRef $stagingRef -SupabaseUrl "https://$productionRef.supabase.co" -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -RepoRoot $repoRoot -IgnoreLinkedRef
}
Assert-Throws -Name 'same staging/production refs' -Script {
  Assert-TargetContract -Environment staging -ProjectRef $stagingRef -SupabaseUrl "https://$stagingRef.supabase.co" -StagingProjectRef $stagingRef -ProductionProjectRef $stagingRef -RepoRoot $repoRoot -IgnoreLinkedRef
}

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "wp228-guard-$([guid]::NewGuid().ToString('N'))"
try {
  $linkedDirectory = Join-Path $fixtureRoot 'supabase\.temp'
  [IO.Directory]::CreateDirectory($linkedDirectory) | Out-Null
  [IO.File]::WriteAllText((Join-Path $linkedDirectory 'project-ref'), $productionRef)
  Assert-Throws -Name 'stale CLI link' -Script {
    Assert-TargetContract -Environment staging -ProjectRef $stagingRef -SupabaseUrl "https://$stagingRef.supabase.co" -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -RepoRoot $fixtureRoot
  }
} finally {
  if ([IO.Directory]::Exists($fixtureRoot)) { [IO.Directory]::Delete($fixtureRoot, $true) }
}

foreach ($arguments in @(
  @('db', 'reset', '--linked'),
  @('db', 'reset', '--db-url', 'postgres://example'),
  @('migration', 'repair', '--status', 'applied'),
  @('db', 'query', 'truncate table public.study_sessions')
)) {
  Assert-Throws -Name "deny $($arguments -join ' ')" -Script { Assert-SafeSupabaseArguments -Arguments $arguments }
}

Assert-SafeSupabaseArguments -Arguments @('db', 'reset')
$passed++
Assert-SafeSupabaseArguments -Arguments @('db', 'push', '--linked', '--dry-run')
$passed++

$inspectSql = Get-StagingPrerequisiteSql -Action inspect
$bootstrapSql = Get-StagingPrerequisiteSql -Action bootstrap
Assert-StagingPrerequisiteAction -Action inspect -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $inspectSql
$passed++
Assert-StagingPrerequisiteAction -Action bootstrap -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $bootstrapSql
$passed++
Assert-Throws -Name 'prerequisite production target denied' -Script {
  Assert-StagingPrerequisiteAction -Action bootstrap -Environment production -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $bootstrapSql
}
Assert-Throws -Name 'arbitrary prerequisite SQL denied' -Script {
  Assert-StagingPrerequisiteAction -Action bootstrap -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql 'create extension if not exists http;'
}
Assert-Throws -Name 'production ref masquerading as staging denied' -Script {
  Assert-StagingPrerequisiteAction -Action bootstrap -Environment staging -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $bootstrapSql
}

$pushDispatchPostCheckSql = Get-StagingPushDispatchPostCheckSql
Assert-StagingPushDispatchPostCheck -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushDispatchPostCheckSql
$passed++
foreach ($requiredMarker in @('pg_net', "n.nspname = 'net'", "p.proname = 'http_post'")) {
  if ($pushDispatchPostCheckSql -notmatch [regex]::Escape($requiredMarker)) {
    throw "Push dispatch post-check is missing: $requiredMarker"
  }
}
$passed++
Assert-Throws -Name 'push dispatch post-check production target denied' -Script {
  Assert-StagingPushDispatchPostCheck -Environment production -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushDispatchPostCheckSql
}
Assert-Throws -Name 'arbitrary push dispatch post-check SQL denied' -Script {
  Assert-StagingPushDispatchPostCheck -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql 'select 1;'
}
Assert-Throws -Name 'production ref push dispatch post-check masquerade denied' -Script {
  Assert-StagingPushDispatchPostCheck -Environment staging -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushDispatchPostCheckSql
}

$pushRuntimeDiagnosticSql = Get-StagingPushRuntimeDiagnosticSql
Assert-StagingPushRuntimeDiagnostic -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushRuntimeDiagnosticSql
$passed++
foreach ($requiredMarker in @(
  'begin transaction read only',
  'cron.job_run_details',
  'pg_net_catalog',
  'pg_extension',
  'pg_proc',
  'push_dispatch_runtime_config',
  'get_push_dispatch_queue_health',
  'notification_deliveries',
  'available_now',
  'device_disabled',
  'preference_enabled',
  'rollback'
)) {
  if ($pushRuntimeDiagnosticSql -notmatch [regex]::Escape($requiredMarker)) {
    throw "Push runtime diagnostic is missing: $requiredMarker"
  }
}
$passed++
foreach ($forbiddenOutput in @('fcm_token', 'payload', 'provider_message_id', 'recipient_id', 'installation_id')) {
  if ($pushRuntimeDiagnosticSql -match "\b$forbiddenOutput\b") {
    throw "Push runtime diagnostic exposes a sensitive field: $forbiddenOutput"
  }
}
$passed++
Assert-Throws -Name 'push runtime diagnostic production target denied' -Script {
  Assert-StagingPushRuntimeDiagnostic -Environment production -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushRuntimeDiagnosticSql
}
Assert-Throws -Name 'push runtime diagnostic arbitrary SQL denied' -Script {
  Assert-StagingPushRuntimeDiagnostic -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql 'select * from public.push_dispatch_runtime_config;'
}
Assert-Throws -Name 'push runtime diagnostic production ref masquerade denied' -Script {
  Assert-StagingPushRuntimeDiagnostic -Environment staging -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushRuntimeDiagnosticSql
}

$v3CompatibilitySql = Get-V3LegacyCompatibilitySql
Assert-V3LegacyCompatibilityInspection -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $v3CompatibilitySql
$passed++
Assert-V3LegacyCompatibilityInspection -Environment production -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $v3CompatibilitySql
$passed++
foreach ($requiredMarker in @('select json_build_object', 'live_study_runs', 'open_run_counts', 'active_run_indexes', 'status_constraints')) {
  if ($v3CompatibilitySql -notmatch [regex]::Escape($requiredMarker)) {
    throw "V3 compatibility inspection is missing: $requiredMarker"
  }
}
$passed++
Assert-Throws -Name 'v3 compatibility arbitrary SQL denied' -Script {
  Assert-V3LegacyCompatibilityInspection -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql 'select * from public.live_study_runs;'
}
Assert-Throws -Name 'v3 compatibility production ref masquerade denied' -Script {
  Assert-V3LegacyCompatibilityInspection -Environment staging -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $v3CompatibilitySql
}

$pushDiagnosticWorkflowPath = Join-Path $repoRoot '.github\workflows\staging-push-diagnostics.yml'
$pushDiagnosticWorkflow = Get-Content -LiteralPath $pushDiagnosticWorkflowPath -Raw -Encoding UTF8
if ($pushDiagnosticWorkflow -notmatch '(?m)^\s*workflow_dispatch:\s*$' -or
    $pushDiagnosticWorkflow -match '(?m)^\s*push:\s*$' -or
    $pushDiagnosticWorkflow -notmatch 'Action\s*=\s*''inspect-push-runtime''' -or
    $pushDiagnosticWorkflow -match 'staging-apply|production-apply|Action\s*=\s*''apply''|db push') {
  throw 'Staging push diagnostics workflow must remain manual and read-only.'
}
$passed++

$reconciliationPrepareSql = Get-StagingReconciliationSql -Action prepare
$reconciliationPrepareInspectSql = Get-StagingReconciliationSql -Action prepare-inspect
$reconciliationApplySql = Get-StagingReconciliationSql -Action apply
$reconciliationApplyInspectSql = Get-StagingReconciliationSql -Action apply-inspect
Assert-StagingReconciliationAction -Action prepare -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationPrepareSql
$passed++
Assert-StagingReconciliationAction -Action prepare-inspect -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationPrepareInspectSql
$passed++
Assert-StagingReconciliationAction -Action apply -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationApplySql
$passed++
Assert-StagingReconciliationAction -Action apply-inspect -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationApplyInspectSql
$passed++
Assert-Throws -Name 'reconciliation production target denied' -Script {
  Assert-StagingReconciliationAction -Action apply -Environment production -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationApplySql
}
Assert-Throws -Name 'arbitrary reconciliation SQL denied' -Script {
  Assert-StagingReconciliationAction -Action prepare -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql 'select public.prepare_equal_source_reconciliation(500, null);'
}
Assert-Throws -Name 'production ref reconciliation masquerade denied' -Script {
  Assert-StagingReconciliationAction -Action prepare -Environment staging -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationPrepareSql
}

$backfillInspectSql = Get-GoalBackfillSql -Action inspect
$backfillWriteSql = Get-GoalBackfillSql -Action backfill
Assert-GoalBackfillAction -Action inspect -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $backfillInspectSql
$passed++
Assert-GoalBackfillAction -Action backfill -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $backfillWriteSql
$passed++
# Reconciliation'dan farkli olarak backfill production'da da mesrudur (insert-only,
# yaprak tablo); production onayi remote.ps1'de ayrica zorunlu tutulur.
Assert-GoalBackfillAction -Action backfill -Environment production -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $backfillWriteSql
$passed++
Assert-Throws -Name 'backfill ref masquerade denied' -Script {
  Assert-GoalBackfillAction -Action backfill -Environment staging -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $backfillWriteSql
}
Assert-Throws -Name 'arbitrary backfill SQL denied' -Script {
  Assert-GoalBackfillAction -Action backfill -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql 'select public.backfill_goal_completions();'
}
Assert-Throws -Name 'backfill inspection may not write' -Script {
  Assert-GoalBackfillAction -Action inspect -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $backfillWriteSql
}
# Kapinin kendisi kirik girdiyle sinanir: yazici SQL'i denetimden gecse bile
# `Assert-SafeSupabaseArguments` yikici fiilleri reddetmeye devam etmelidir.
Assert-Throws -Name 'destructive backfill argument denied' -Script {
  Assert-SafeSupabaseArguments -Arguments @('db', 'query', '--linked', 'delete from public.goal_progress_events;')
}
# Uzak yol gercekten bagli mi: remote.ps1 ve workflow ikisi de tanimali.
$remoteScriptText = Get-Content -LiteralPath (Join-Path $repoRoot 'tooling\supabase\remote.ps1') -Raw -Encoding UTF8
if ($remoteScriptText -notmatch "Action -eq 'backfill-goals'" -or
    $remoteScriptText -notmatch "'apply', 'manual-push-0066-0070', 'backfill-goals'") {
  throw 'remote.ps1 must implement backfill-goals and gate it behind production approval.'
}
$passed++
if ($databaseWorkflow -notmatch 'staging-backfill-goals' -or
    $databaseWorkflow -notmatch 'production-backfill-goals' -or
    $databaseWorkflow -notmatch "'production-backfill-goals' \{ 'backfill-goals' \}") {
  throw 'Database Gates must expose both backfill-goals operations with an explicit mapping.'
}
$passed++

$sha = '0123456789abcdef0123456789abcdef01234567'
$confirmation = "PRODUCTION GO:$sha`:0063`:$productionRef"
$backup = '{"backup_id":"backup-123","captured_at_utc":"2026-07-20T10:00:00Z","restore_strategy":"point-in-time recovery verified","session_baseline_evidence":"artifact/session.json","xp_reconciliation_evidence":"artifact/xp.json","post_check_plan":"artifact/post-check.json"}'
Assert-Throws -Name 'production environment approval required' -Script {
  Assert-ProductionApproval -ExpectedGitSha $sha -ExpectedMigrationHead '0063' -ProjectRef $productionRef -BackupEvidence $backup -Confirmation $confirmation -GitHubActions 'false' -ApprovalEnvironment 'production'
}
Assert-Throws -Name 'production backup required' -Script {
  Assert-ProductionApproval -ExpectedGitSha $sha -ExpectedMigrationHead '0063' -ProjectRef $productionRef -BackupEvidence 'skip' -Confirmation $confirmation -GitHubActions 'true' -ApprovalEnvironment 'production'
}
Assert-Throws -Name 'exact production GO required' -Script {
  Assert-ProductionApproval -ExpectedGitSha $sha -ExpectedMigrationHead '0063' -ProjectRef $productionRef -BackupEvidence $backup -Confirmation 'PRODUCTION GO' -GitHubActions 'true' -ApprovalEnvironment 'production'
}
Assert-ProductionApproval -ExpectedGitSha $sha -ExpectedMigrationHead '0063' -ProjectRef $productionRef -BackupEvidence $backup -Confirmation $confirmation -GitHubActions 'true' -ApprovalEnvironment 'production'
$passed++

# Backup kanıtı artık API yanıtından türetilir; kanıt yoksa apply açılmaz.
$now = [DateTimeOffset]::Parse('2026-07-27T00:00:00Z')
Assert-Throws -Name 'backup evidence requires a real recovery point' -Script {
  New-ProductionBackupEvidence -BackupApiResponse ([pscustomobject]@{ pitr_enabled = $false; backups = @() }) `
    -ProjectRef $productionRef -ExpectedGitSha $sha -ExpectedMigrationHead '0085' -NowUtc $now
}
Assert-Throws -Name 'stale backup rejected' -Script {
  New-ProductionBackupEvidence -BackupApiResponse ([pscustomobject]@{ pitr_enabled = $false; backups = @(
    [pscustomobject]@{ status = 'COMPLETED'; inserted_at = '2026-07-20T00:00:00Z' }) }) `
    -ProjectRef $productionRef -ExpectedGitSha $sha -ExpectedMigrationHead '0085' -NowUtc $now
}
Assert-Throws -Name 'incomplete backup rejected' -Script {
  New-ProductionBackupEvidence -BackupApiResponse ([pscustomobject]@{ pitr_enabled = $false; backups = @(
    [pscustomobject]@{ status = 'PENDING'; inserted_at = '2026-07-26T22:00:00Z' }) }) `
    -ProjectRef $productionRef -ExpectedGitSha $sha -ExpectedMigrationHead '0085' -NowUtc $now
}
# Baseline onarımı: yalnız 0001-0070'i applied işaretler, şemaya DDL göndermez.
$repairArguments = Get-ProductionBaselineRepairArguments -BaselineHead '0070' -RepoRoot $repoRoot
Assert-Equal $repairArguments[0] 'migration' 'baseline repair komutu'
Assert-Equal ($repairArguments -contains '0070') $true 'baseline 0070 dahil'
Assert-Equal ($repairArguments -contains '0071') $false 'baseline 0071 haric'
Assert-Equal ($repairArguments -contains '0085') $false 'baseline 0085 haric'
Assert-Throws -Name 'baseline repair blocked outside production' -Script {
  Assert-ProductionBaselineRepair -Environment staging -ProjectRef $stagingRef -ProductionProjectRef $productionRef `
    -Arguments $repairArguments -BaselineHead '0070' -GitHubActions 'true' -ApprovalEnvironment 'production'
}
Assert-Throws -Name 'baseline repair blocked outside CI' -Script {
  Assert-ProductionBaselineRepair -Environment production -ProjectRef $productionRef -ProductionProjectRef $productionRef `
    -Arguments $repairArguments -BaselineHead '0070' -GitHubActions 'false' -ApprovalEnvironment 'production'
}
Assert-Throws -Name 'baseline repair rejects newer versions' -Script {
  Assert-ProductionBaselineRepair -Environment production -ProjectRef $productionRef -ProductionProjectRef $productionRef `
    -Arguments (@('migration', 'repair', '--linked', '--status', 'applied', '0085')) -BaselineHead '0070' `
    -GitHubActions 'true' -ApprovalEnvironment 'production'
}
Assert-Throws -Name 'baseline repair rejects reverted status' -Script {
  Assert-ProductionBaselineRepair -Environment production -ProjectRef $productionRef -ProductionProjectRef $productionRef `
    -Arguments (@('migration', 'repair', '--linked', '--status', 'reverted', '0070')) -BaselineHead '0070' `
    -GitHubActions 'true' -ApprovalEnvironment 'production'
}
Assert-ProductionBaselineRepair -Environment production -ProjectRef $productionRef -ProductionProjectRef $productionRef `
  -Arguments $repairArguments -BaselineHead '0070' -GitHubActions 'true' -ApprovalEnvironment 'production'
$passed++
# `migration repair` yalnız bu dar yolda serbesttir.
Assert-Throws -Name 'migration repair denied by default' -Script {
  Assert-SafeSupabaseArguments -Arguments $repairArguments
}
Assert-SafeSupabaseArguments -Arguments $repairArguments -AllowBaselineRepair
$passed++

Assert-Equal ([string]$contract.production.backup_requirement) 'waived' 'sahip kararı: production yedeksiz apply'
Assert-Throws -Name 'incomplete waiver rejected' -Script {
  New-ProductionBackupEvidence -BackupApiResponse $null -ProjectRef $productionRef -ExpectedGitSha $sha `
    -ExpectedMigrationHead '0085' -BackupWaiver ([pscustomobject]@{ decided_by = 'owner'; reason = '' })
}
$waived = New-ProductionBackupEvidence -BackupApiResponse $null -ProjectRef $productionRef -ExpectedGitSha $sha `
  -ExpectedMigrationHead '0085' -BackupWaiver $contract.production.backup_waiver
if ($waived.restore_strategy -notlike 'NONE - owner waived*') { throw 'Waived evidence must state that no rollback exists.' }
$passed++
$freshBackup = New-ProductionBackupEvidence -BackupApiResponse ([pscustomobject]@{ pitr_enabled = $false; backups = @(
  [pscustomobject]@{ status = 'COMPLETED'; inserted_at = '2026-07-26T20:00:00Z'; id = 'bkp-77' }) }) `
  -ProjectRef $productionRef -ExpectedGitSha $sha -ExpectedMigrationHead '0085' -NowUtc $now
Assert-Equal $freshBackup.backup_id "daily:$productionRef`:bkp-77" 'fresh daily backup id'
# Türetilen kanıt, production onay kapısını olduğu gibi geçmelidir.
$derivedConfirmation = "PRODUCTION GO:$sha`:0085`:$productionRef"
Assert-ProductionApproval -ExpectedGitSha $sha -ExpectedMigrationHead '0085' -ProjectRef $productionRef `
  -BackupEvidence ($freshBackup | ConvertTo-Json -Depth 6 -Compress) -Confirmation $derivedConfirmation `
  -GitHubActions 'true' -ApprovalEnvironment 'production'
$passed++
if ($databaseWorkflow -notmatch 'backup-evidence\.ps1' -or $databaseWorkflow -notmatch 'RESOLVED_BACKUP_EVIDENCE') {
  throw 'Database Gates must resolve production backup evidence from Supabase.'
}
$passed++

$secret = 'sb_secret_should_never_leak'
$redacted = Protect-DeployText -Text "token=$secret Bearer access-token postgres://user:password@host/db eyJaaa.bbb.ccc`n`"JWT_SECRET`": `"local-jwt`"`n`"S3_PROTOCOL_ACCESS_KEY_SECRET`": `"local-s3`"" -SensitiveValues @($secret)
if ($redacted.Contains($secret) -or $redacted.Contains('access-token') -or $redacted.Contains('password') -or $redacted.Contains('eyJaaa') -or $redacted.Contains('local-jwt') -or $redacted.Contains('local-s3')) {
  throw 'Secret redaction test failed.'
}
$passed++

Write-Host "Deploy guard tests: $passed passed."
