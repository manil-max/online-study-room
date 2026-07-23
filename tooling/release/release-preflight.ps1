[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('beta', 'stable')][string]$Channel,
  [Parameter(Mandatory)][string]$Tag,
  [Parameter(Mandatory)][string]$ExpectedGitSha,
  [Parameter(Mandatory)][string]$ExpectedMigrationHead,
  [string]$ProjectRef,
  [string]$SupabaseUrl,
  [string]$StagingProjectRef,
  [string]$ProductionProjectRef,
  [string]$ProductionConfirmation,
  [string]$ProductionEvidence,
  [switch]$ValidateOnly,
  [string]$EvidenceRoot
)

$ErrorActionPreference = 'Stop'
$guardModule = Join-Path $PSScriptRoot '..\supabase\DeployGuard.psm1'
Import-Module $guardModule -Force

$repoRoot = Get-RepoRoot
$expectedPattern = if ($Channel -eq 'beta') { '^beta-v(?<code>\d+)$' } else { '^v(?<code>\d+)$' }
if ($Tag -notmatch $expectedPattern) {
  throw "Tag '$Tag' does not match channel '$Channel'."
}
$code = [int]$Matches.code
if ($Channel -eq 'beta') {
  $patch = [math]::Floor($code / 100)
  $sequence = $code % 100
  if ($patch -lt 1 -or $sequence -lt 1 -or $sequence -gt 99) {
    throw 'Beta tag must encode patch*100+sequence, with sequence 1-99.'
  }
  $versionName = "1.0.$patch-beta.$sequence"
  $environment = 'staging'
} else {
  if ($code -lt 1) { throw 'Stable tag code must be positive.' }
  $versionName = "1.0.$code"
  $environment = 'production'
}

Assert-ExactReleaseIdentity -ExpectedGitSha $ExpectedGitSha -ExpectedMigrationHead $ExpectedMigrationHead -RepoRoot $repoRoot
$contract = Get-DeployContract -RepoRoot $repoRoot
if ($contract.$environment.migration_head -ne $ExpectedMigrationHead) {
  throw "Release contract rejects migration head $ExpectedMigrationHead for $Channel."
}

$result = [ordered]@{
  schema_version = 1
  kind = 'release-preflight'
  tag = $Tag
  channel = $Channel
  environment = $environment
  version_name = $versionName
  build_number = $code
  git_sha = $ExpectedGitSha
  migration_head = $ExpectedMigrationHead
}

if (-not $ValidateOnly) {
  if ([string]::IsNullOrWhiteSpace($ProjectRef) -or [string]::IsNullOrWhiteSpace($SupabaseUrl) -or
      [string]::IsNullOrWhiteSpace($StagingProjectRef) -or [string]::IsNullOrWhiteSpace($ProductionProjectRef)) {
    throw 'Real preflight requires target URL/project-ref and both environment project refs.'
  }
  & (Join-Path $PSScriptRoot 'release-gate.ps1') -Channel $Channel -ProjectRef $ProjectRef -SupabaseUrl $SupabaseUrl `
    -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef `
    -ExpectedGitSha $ExpectedGitSha -ExpectedMigrationHead $ExpectedMigrationHead `
    -ProductionConfirmation $ProductionConfirmation -ProductionEvidence $ProductionEvidence -EvidenceRoot $EvidenceRoot
}

$result | ConvertTo-Json -Depth 4
