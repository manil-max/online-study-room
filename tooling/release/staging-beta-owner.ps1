[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ExpectedGitSha,
  [string]$ExpectedMigrationHead = '0064',
  [string]$VersionName = '1.0.42-beta.1',
  [string]$BuildNumber = '4201',
  [string]$StagingProjectRef = 'rskiuyjabyzelqododpa',
  [string]$ProductionProjectRef = 'jiphfrpzvkpzubbkhrwb',
  [string]$NodePath = 'C:\Users\muhlis2\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
)

$ErrorActionPreference = 'Stop'
$guardModule = Join-Path $PSScriptRoot '..\supabase\DeployGuard.psm1'
Import-Module $guardModule -Force

$repoRoot = Get-RepoRoot
$cliEntry = Join-Path $repoRoot 'node_modules\supabase\dist\supabase.js'
$supabaseUrl = "https://$StagingProjectRef.supabase.co"
$rawKeys = $null
$publicKey = $null

try {
  Assert-TargetContract -Environment staging -ProjectRef $StagingProjectRef -SupabaseUrl $supabaseUrl -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef -RepoRoot $repoRoot -IgnoreLinkedRef
  Assert-ExactReleaseIdentity -ExpectedGitSha $ExpectedGitSha -ExpectedMigrationHead $ExpectedMigrationHead -RepoRoot $repoRoot
  if (-not (Test-Path -LiteralPath $NodePath) -or -not (Test-Path -LiteralPath $cliEntry)) {
    throw 'Pinned Node/Supabase CLI runtime is missing.'
  }

  $rawKeys = (& $NodePath $cliEntry projects api-keys --project-ref $StagingProjectRef --output json --workdir $repoRoot 2>$null | Out-String)
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read the staging public API key through the authenticated CLI profile.'
  }
  try { $keyRecords = $rawKeys | ConvertFrom-Json } catch {
    throw 'Staging API key response was not valid JSON.'
  }

  $selected = $keyRecords | Where-Object { $_.type -eq 'publishable' } | Select-Object -First 1
  if (-not $selected) {
    $selected = $keyRecords | Where-Object { $_.name -eq 'anon' -and $_.type -eq 'legacy' } | Select-Object -First 1
  }
  $publicKey = [string]$selected.api_key
  if ([string]::IsNullOrWhiteSpace($publicKey) -or $publicKey.StartsWith('sb_secret_') -or $publicKey.ToLowerInvariant().Contains('service_role')) {
    throw 'A client-safe staging API key could not be selected.'
  }

  $env:STAGING_SUPABASE_ANON_KEY = $publicKey
  & (Join-Path $PSScriptRoot 'beta-build.ps1') `
    -ProjectRef $StagingProjectRef `
    -SupabaseUrl $supabaseUrl `
    -StagingProjectRef $StagingProjectRef `
    -ProductionProjectRef $ProductionProjectRef `
    -ExpectedGitSha $ExpectedGitSha `
    -ExpectedMigrationHead $ExpectedMigrationHead `
    -VersionName $VersionName `
    -BuildNumber $BuildNumber
} finally {
  Remove-Item Env:STAGING_SUPABASE_ANON_KEY -ErrorAction SilentlyContinue
  $publicKey = $null
  $rawKeys = $null
}
