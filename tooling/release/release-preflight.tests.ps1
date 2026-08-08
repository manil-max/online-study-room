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

# Jargon sozlesmesi: kullaniciya gorunen notlarda teknik metin olmayacak.
& (Join-Path $repoRoot 'tooling/release/release-notes-contract.ps1') `
  -UserNotesPath (Join-Path $repoRoot 'app/assets/release_notes.json') `
  -TechnicalLogPath (Join-Path $repoRoot 'tooling/release/release_notes_technical.json') | Out-Null

Write-Host 'Release preflight tests: 9 passed (release-notes gate included).'
