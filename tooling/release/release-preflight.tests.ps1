$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Import-Module (Join-Path $repoRoot 'tooling\supabase\DeployGuard.psm1') -Force
$script = Join-Path $repoRoot 'tooling\release\release-preflight.ps1'
$sha = Get-GitHead -RepoRoot $repoRoot

& $script -Channel beta -Tag beta-v4307 -ExpectedGitSha $sha -ExpectedMigrationHead '0070' -ValidateOnly | Out-Null
$cases = @(
  @{ Name = 'wrong SHA'; Channel = 'beta'; Tag = 'beta-v4307'; Sha = ('0' * 40); Head = '0070' },
  @{ Name = 'wrong head'; Channel = 'beta'; Tag = 'beta-v4307'; Sha = $sha; Head = '0068' },
  @{ Name = 'wrong channel/tag'; Channel = 'stable'; Tag = 'beta-v4307'; Sha = $sha; Head = '0065' }
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
  'finalize_beta_android:',
  'needs: [preflight, android]',
  "needs.preflight.outputs.channel == 'beta'",
  "'requiredPlatforms': ['android']",
  "'optionalPlatforms': [{'platform': 'windows', 'status': 'building'}]",
  'finalize_complete:',
  "if: needs.preflight.outputs.channel == 'stable'"
)) {
  if ($releaseWorkflow -notmatch [regex]::Escape($requiredMarker)) {
    throw "Release workflow is missing Android-first beta contract: $requiredMarker"
  }
}
if ($releaseWorkflow -match 'files:\s*release-assets/\*\*') {
  throw 'Release upload must use explicit public assets; recursive upload reintroduces duplicate platform manifest names.'
}

Write-Host 'Release preflight tests: 7 passed.'
