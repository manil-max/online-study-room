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

Write-Host 'Release preflight tests: 8 passed.'
