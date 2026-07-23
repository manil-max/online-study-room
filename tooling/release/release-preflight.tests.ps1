$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Import-Module (Join-Path $repoRoot 'tooling\supabase\DeployGuard.psm1') -Force
$script = Join-Path $repoRoot 'tooling\release\release-preflight.ps1'
$sha = Get-GitHead -RepoRoot $repoRoot

& $script -Channel beta -Tag beta-v4304 -ExpectedGitSha $sha -ExpectedMigrationHead '0068' -ValidateOnly | Out-Null
$cases = @(
  @{ Name = 'wrong SHA'; Channel = 'beta'; Tag = 'beta-v4304'; Sha = ('0' * 40); Head = '0068' },
  @{ Name = 'wrong head'; Channel = 'beta'; Tag = 'beta-v4304'; Sha = $sha; Head = '0065' },
  @{ Name = 'wrong channel/tag'; Channel = 'stable'; Tag = 'beta-v4304'; Sha = $sha; Head = '0065' }
)
foreach ($case in $cases) {
  $failed = $false
  try {
    & $script -Channel $case.Channel -Tag $case.Tag -ExpectedGitSha $case.Sha -ExpectedMigrationHead $case.Head -ValidateOnly | Out-Null
  } catch { $failed = $true }
  if (-not $failed) { throw "Expected failure did not occur: $($case.Name)" }
}
Write-Host 'Release preflight tests: 4 passed.'
