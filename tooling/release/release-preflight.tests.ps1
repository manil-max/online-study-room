$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Import-Module (Join-Path $repoRoot 'tooling\supabase\DeployGuard.psm1') -Force
$script = Join-Path $repoRoot 'tooling\release\release-preflight.ps1'
$sha = Get-GitHead -RepoRoot $repoRoot
# Yerel head sabit sayiyla pinlenmez (bkz. guard.tests.ps1); tek kaynak
# migration dizini. Asagidaki negatif senaryolar bilerek yanlis head kullanir.
$head = Get-LocalMigrationHead -RepoRoot $repoRoot

# WP-469: preflight iki sarti birden arar — yerel head beklenen head'e esit
# OLMALI **ve** hedef ortamin kontrat head'i de ayni olmali. Yani beta ancak
# yerel semanin staging'e gercekten uygulanmis olmasi halinde gecebilir.
#
# Bu iki durum da mesrudur ve test ikisini de anlamli tutar:
#   * yerel head == staging head  -> pozitif senaryo gecmeli,
#   * yerel head staging'in onunde -> preflight **fail-closed** dusmeli.
# v57 turu `0101`-`0108`i yazdi ama hicbirini uygulamadi; su an ikinci
# durumdayiz ve pozitif senaryoyu zorlamak "uygulanmamis semayla beta cikar"
# demek olurdu. Kontrati staging'i 0108 yazacak sekilde "duzeltmek" ayni
# yalanin baska turudur; staging head'i yalniz gercek apply sonrasi ilerler.
$stagingHead = (Get-DeployContract -RepoRoot $repoRoot).staging.migration_head
$productionHead = (Get-DeployContract -RepoRoot $repoRoot).production.migration_head
if ($head -eq $stagingHead) {
  & $script -Channel beta -Tag beta-v4402 -ExpectedGitSha $sha -ExpectedMigrationHead $head -ValidateOnly | Out-Null
} else {
  $failed = $false
  try {
    & $script -Channel beta -Tag beta-v4402 -ExpectedGitSha $sha -ExpectedMigrationHead $head -ValidateOnly | Out-Null
  } catch { $failed = $true }
  if (-not $failed) {
    throw "Preflight must fail closed while local head $head is ahead of staging $stagingHead."
  }
  Write-Host "Local head $head is ahead of staging $stagingHead; beta preflight correctly fails closed."
}
$cases = @(
  @{ Name = 'wrong SHA'; Channel = 'beta'; Tag = 'beta-v4402'; Sha = ('0' * 40); Head = $head },
  @{ Name = 'wrong head'; Channel = 'beta'; Tag = 'beta-v4402'; Sha = $sha; Head = '0068' },
  @{ Name = 'stable contract rejects old production head'; Channel = 'stable'; Tag = 'v45'; Sha = $sha; Head = '0070' },
  @{ Name = 'stable head behind source (v45 loophole)'; Channel = 'stable'; Tag = 'v45'; Sha = $sha; Head = '0065' },
  @{ Name = 'wrong channel/tag'; Channel = 'stable'; Tag = 'beta-v4402'; Sha = $sha; Head = '0065' }
)
foreach ($case in $cases) {
  $failed = $false
  try {
    & $script -Channel $case.Channel -Tag $case.Tag -ExpectedGitSha $case.Sha -ExpectedMigrationHead $case.Head -ValidateOnly | Out-Null
  } catch { $failed = $true }
  if (-not $failed) { throw "Expected failure did not occur: $($case.Name)" }
}

$releaseWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\release.yml') -Raw -Encoding UTF8
if ($releaseWorkflow -notmatch 'if \[ "\$SRC" != "\$OUT" \]; then mv -- "\$SRC" "\$OUT"; fi' -or
    $releaseWorkflow -notmatch 'test -f "\$OUT"') {
  throw 'Android artifact packaging must tolerate identical source/output names and verify the output.'
}
foreach ($requiredMarker in @(
  'finalize_android:',
  'needs: [preflight, android]',
  "'requiredPlatforms': ['android']",
  "'optionalPlatforms': [{'platform': 'windows', 'status': 'building'}]",
  'finalize_complete:',
  "prerelease: `$`{{ needs.preflight.outputs.channel == 'beta' }}",
  'PRODUCTION_SUPABASE_URL'
)) {
  if ($releaseWorkflow -notmatch [regex]::Escape($requiredMarker)) {
    throw "Release workflow is missing Android-first channel contract: $requiredMarker"
  }
}
if ($releaseWorkflow -match 'files:\s*release-assets/\*\*') {
  throw 'Release upload must use explicit public assets; recursive upload reintroduces duplicate platform manifest names.'
}

# ---------------------------------------------------------------------------
# WP-518: yayin notlari kapisi
#
# 🔴 Bu kapinin varlik sebebi olculdu, tahmin degil: v59 etiketi 2026-08-07'de
# atildi, GitHub Release olustu, APK 5 kez indirildi — ama ne CHANGELOG'da ne
# `app/assets/release_notes.json`'da kaydi vardi. Kullanici uygulama icindeki
# "Guncelleme notlari" ekranini BOS gordu. `.agents/AGENTS.md` §4.1 bu iki
# kaydi zorunlu tutuyordu; zorlayan hicbir kapi yoktu.
#
# `release-notes-contract.ps1` de bu bosluga bakmiyordu (yalniz jargon
# denetler) ve dahasi hicbir workflow onu cagirmiyordu. Iki eksik de burada
# kapaniyor: varlik denetimi asagida, jargon denetimi en sonda kosuyor.
# ---------------------------------------------------------------------------
foreach ($present in @(
  @{ Tag = 'v58'; Channel = 'stable'; Build = 58 },
  @{ Tag = 'v59'; Channel = 'stable'; Build = 59 },
  @{ Tag = 'beta-v4402'; Channel = 'beta'; Build = 4402 }
)) {
  Assert-ReleaseNotesEntry -Tag $present.Tag -Channel $present.Channel -BuildNumber $present.Build -RepoRoot $repoRoot
}

# Negatif: hic var olmayan etiket, ve VAR OLAN etiketin YANLIS build numarasi.
# Ikincisi onemli — yalniz CHANGELOG basligina bakan bir kapi onu kacirirdi.
foreach ($missing in @(
  @{ Name = 'unknown tag'; Tag = 'v999'; Channel = 'stable'; Build = 999 },
  @{ Name = 'changelog ok but notes entry missing'; Tag = 'v58'; Channel = 'stable'; Build = 9958 },
  @{ Name = 'right build, wrong channel'; Tag = 'v58'; Channel = 'beta'; Build = 58 }
)) {
  $failed = $false
  try {
    Assert-ReleaseNotesEntry -Tag $missing.Tag -Channel $missing.Channel -BuildNumber $missing.Build -RepoRoot $repoRoot
  } catch { $failed = $true }
  if (-not $failed) {
    throw "Release-notes gate must fail closed: $($missing.Name)"
  }
}

# Preflight bu denetimi GERCEKTEN cagiriyor mu? Fonksiyon var olup cagrilmazsa
# kapi yine oksuz kalir — v59 hatasi tam bu sinifta.
$preflightSource = Get-Content -LiteralPath $script -Raw -Encoding UTF8
if ($preflightSource -notmatch 'Assert-ReleaseNotesEntry') {
  throw 'release-preflight.ps1 must call Assert-ReleaseNotesEntry; an uncalled gate is not a gate.'
}

# ---------------------------------------------------------------------------
# WP-527: Play AAB kapisi
#
# Play Console yeni uygulamada APK kabul etmez, AAB ister. Adim release.yml'den
# duserse yayin turu yesil biter ama Play'e yuklenecek artefakt hic uretilmemis
# olur. Bu repoda "kural yaziliydi, cagiran yoktu" hatasi iki kez uretime cikti;
# bu yuzden kapi hem POZITIF hem de KIRIK GIRDI ile olculur.
# ---------------------------------------------------------------------------

# WP-564: STABLE head simetrisi -- beta kolundakiyle ayni kural.
#
# Eskiden burada KOSULSUZ bir pozitif vardi ve yerel head'i bekliyordu. Yerel
# head production'in onune gectigi anda (migration yazildi, production'a henuz
# uygulanmadi) bu satir kapiyi kirmiziya dusuruyordu -- kod dogruyken.
# Dogru iddia: yerel head production'a esitse stable preflight GECMELI, degilse
# FAIL-CLOSED dusmeli. Ikisi de mesru durum; kontrati "duzeltmek" (production
# head'ini elle ilerletmek) uygulanmamis semayla yayin yapmak demek olurdu.
if ($head -eq $productionHead) {
  & $script -Channel stable -Tag v60 -ExpectedGitSha $sha -ExpectedMigrationHead $head -ValidateOnly | Out-Null
} else {
  $failed = $false
  $message = ''
  try {
    & $script -Channel stable -Tag v60 -ExpectedGitSha $sha -ExpectedMigrationHead $head -ValidateOnly | Out-Null
  } catch { $failed = $true; $message = $_.Exception.Message }
  if (-not $failed) {
    throw "Preflight must fail closed while local head $head is ahead of production $productionHead."
  }
  if ($message -notmatch 'Release contract rejects migration head') {
    throw "Stable preflight failed for the wrong reason: $message"
  }
  Write-Host "Local head $head is ahead of production $productionHead; stable preflight correctly fails closed."
}

# WP-564: bundan sonraki WP-527 senaryolari head'i TUTAN gecici bir kontratla
# kosar. Aksi halde negatifler AAB adimi yuzunden degil head uyusmazligi
# yuzunden kirmizi duser ve kapi hicbir sey olcmez (asagida hata mesaji da
# dogrulanir). Gercek `deploy-contract.json` dosyasina DOKUNULMAZ.
$contractObject = Get-DeployContract -RepoRoot $repoRoot
$contractObject.production.migration_head = $head
$contractObject.staging.migration_head = $head
$headSyncedContractPath = Join-Path ([IO.Path]::GetTempPath()) "wp564-contract-$([guid]::NewGuid().ToString('N')).json"
[IO.File]::WriteAllText($headSyncedContractPath, ($contractObject | ConvertTo-Json -Depth 8))

# Pozitif: mevcut release.yml + head'i tutan kontrat ile stable preflight yesil.
& $script -Channel stable -Tag v60 -ExpectedGitSha $sha -ExpectedMigrationHead $head -ValidateOnly -DeployContractPath $headSyncedContractPath | Out-Null

# Kirik girdi: AAB yolunun her bir parcasi tek tek silinmis bir workflow
# kopyasinda kapi KIRMIZI dusmeli. Gercek dosyaya dokunulmaz.
$brokenWorkflowPath = Join-Path ([IO.Path]::GetTempPath()) "wp527-release-$([guid]::NewGuid().ToString('N')).yml"
try {
  foreach ($removal in @(
    @{ Name = 'appbundle build step removed'; Pattern = 'flutter build appbundle[^\r\n]*' },
    @{ Name = 'play env file reference removed'; Pattern = 'env\.play\.json' },
    @{ Name = 'stable-only guard removed'; Pattern = "if: needs\.preflight\.outputs\.channel == 'stable'" },
    @{ Name = 'DISTRIBUTION_CHANNEL=play removed'; Pattern = "DISTRIBUTION_CHANNEL='play'" },
    @{ Name = 'LEGAL_BASE_URL assertion removed'; Pattern = "assert base\['LEGAL_BASE_URL'\]" },
    @{ Name = 'env.json corruption check removed'; Pattern = 'assert again == base' },
    @{ Name = 'aab sha256 step removed'; Pattern = 'sha256sum app-play-release\.aab' },
    @{ Name = 'aab never published as release asset'; Pattern = 'release-assets/android/\*\.aab' }
  )) {
    [IO.File]::WriteAllText($brokenWorkflowPath, ($releaseWorkflow -replace $removal.Pattern, ''))
    $failed = $false
    $message = ''
    try {
      & $script -Channel stable -Tag v60 -ExpectedGitSha $sha -ExpectedMigrationHead $head -ValidateOnly -ReleaseWorkflowPath $brokenWorkflowPath -DeployContractPath $headSyncedContractPath | Out-Null
    } catch { $failed = $true; $message = $_.Exception.Message }
    if (-not $failed) {
      throw "Play AAB gate must fail closed: $($removal.Name)"
    }
    # WP-564: "kirmizi dustu" yetmez -- DOGRU SEBEPLE dusmeli. Bu satir olmadan
    # kapi head uyusmazligi gibi alakasiz bir sebeple de yesil gorunurdu.
    if ($message -notmatch 'Play') {
      throw "Play AAB gate failed for the wrong reason on '$($removal.Name)': $message"
    }
    Write-Host "Play AAB gate red on broken input: $($removal.Name)"
  }

  # Geri al: bozulmamis kopya yine YESIL. Kapi her girdiye kirmizi demiyor.
  [IO.File]::WriteAllText($brokenWorkflowPath, $releaseWorkflow)
  & $script -Channel stable -Tag v60 -ExpectedGitSha $sha -ExpectedMigrationHead $head -ValidateOnly -ReleaseWorkflowPath $brokenWorkflowPath -DeployContractPath $headSyncedContractPath | Out-Null

  # Beta kanali Play'e girmez: AAB'siz workflow beta preflight'i bloklamamali.
  [IO.File]::WriteAllText($brokenWorkflowPath, ($releaseWorkflow -replace 'flutter build appbundle[^\r\n]*', ''))
  if ($head -eq $stagingHead) {
    & $script -Channel beta -Tag beta-v4402 -ExpectedGitSha $sha -ExpectedMigrationHead $head -ValidateOnly -ReleaseWorkflowPath $brokenWorkflowPath | Out-Null
  }
} finally {
  if (Test-Path -LiteralPath $brokenWorkflowPath) {
    Remove-Item -LiteralPath $brokenWorkflowPath -Force
  }
  if (Test-Path -LiteralPath $headSyncedContractPath) {
    Remove-Item -LiteralPath $headSyncedContractPath -Force
  }
}

# WP-564: enjeksiyon bayragi bir ARKA KAPI olmamali -- gercek yayinda kontrat
# her zaman repodaki dosyadan okunmali. Bayragin varsayilani bos oldugu icin
# davranis degismez; burada bunu iddia olarak sabitliyoruz.
$preflightSource = Get-Content -LiteralPath $script -Raw -Encoding UTF8
if ($preflightSource -notmatch '\[string\]\$DeployContractPath') {
  throw 'release-preflight.ps1 must expose -DeployContractPath for the WP-527 gate to measure the AAB step.'
}
if ($preflightSource -notmatch 'IsNullOrWhiteSpace\(\$DeployContractPath\)') {
  throw 'The deploy contract must default to the repository file; an always-injected contract is a back door.'
}
foreach ($workflow in @(
  (Join-Path $repoRoot '.github\workflows\release.yml'),
  (Join-Path $repoRoot '.github\workflows\supabase-deploy.yml')
)) {
  if (-not (Test-Path -LiteralPath $workflow)) { continue }
  $workflowText = Get-Content -LiteralPath $workflow -Raw -Encoding UTF8
  if ($workflowText -match 'DeployContractPath') {
    throw "Workflow must never inject a deploy contract: $workflow"
  }
}

# Jargon sozlesmesi: kullaniciya gorunen notlarda teknik metin olmayacak.
& (Join-Path $repoRoot 'tooling/release/release-notes-contract.ps1') `
  -UserNotesPath (Join-Path $repoRoot 'app/assets/release_notes.json') `
  -TechnicalLogPath (Join-Path $repoRoot 'tooling/release/release_notes_technical.json') | Out-Null

Write-Host 'Release preflight tests: 13 passed (release-notes + Play AAB + WP-564 head symmetry gates included).'
