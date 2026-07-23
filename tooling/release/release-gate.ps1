[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('beta', 'stable')][string]$Channel,
  [Parameter(Mandatory)][string]$ProjectRef,
  [Parameter(Mandatory)][string]$SupabaseUrl,
  [Parameter(Mandatory)][string]$StagingProjectRef,
  [Parameter(Mandatory)][string]$ProductionProjectRef,
  [Parameter(Mandatory)][string]$ExpectedGitSha,
  [Parameter(Mandatory)][string]$ExpectedMigrationHead,
  [string]$ProductionConfirmation,
  [string]$ProductionEvidence,
  [string]$GitHubActions = $env:GITHUB_ACTIONS,
  [string]$ApprovalEnvironment = $env:DEPLOY_APPROVAL_ENVIRONMENT,
  [string]$EvidenceRoot
)

$ErrorActionPreference = 'Stop'
$guardModule = Join-Path $PSScriptRoot '..\supabase\DeployGuard.psm1'
Import-Module $guardModule -Force

$repoRoot = Get-RepoRoot
$environment = if ($Channel -eq 'beta') { 'staging' } else { 'production' }
$evidenceDirectory = New-EvidenceDirectory -Kind "release-$Channel-gate" -EvidenceRoot $EvidenceRoot -RepoRoot $repoRoot
$status = 'failed'
$failure = $null
$productionAuthorizationUsed = $false
$startedAt = (Get-Date).ToUniversalTime()

try {
  Assert-TargetContract -Environment $environment -ProjectRef $ProjectRef -SupabaseUrl $SupabaseUrl -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef -RepoRoot $repoRoot -IgnoreLinkedRef
  Assert-ExactReleaseIdentity -ExpectedGitSha $ExpectedGitSha -ExpectedMigrationHead $ExpectedMigrationHead -RepoRoot $repoRoot
  $contract = Get-DeployContract -RepoRoot $repoRoot
  $targetContract = $contract.$environment
  if ($ExpectedMigrationHead -ne $targetContract.migration_head) {
    throw "Release contract rejects migration head $ExpectedMigrationHead for $Channel."
  }
  if (-not [bool]$targetContract.release_enabled) {
    if ($environment -ne 'production') {
      throw "Release HOLD: $($targetContract.hold_reason)"
    }
    if ([string]::IsNullOrWhiteSpace($ProductionEvidence)) {
      throw 'Production release requires a non-empty staging/QA/soak evidence reference.'
    }
    $expectedConfirmation = "PRODUCTION RELEASE GO:$ExpectedGitSha`:$ExpectedMigrationHead`:$ProjectRef"
    if ($GitHubActions -ne 'true' -or $ApprovalEnvironment -ne 'production') {
      throw 'Production release is CI-only and requires the protected production environment.'
    }
    if ($ProductionConfirmation -cne $expectedConfirmation) {
      throw 'Production release GO does not match the exact commit, migration head and project ref.'
    }
    $productionAuthorizationUsed = $true
  }
  $status = 'success'
} catch {
  $failure = $_.Exception.Message
  throw
} finally {
  $contract = Get-DeployContract -RepoRoot $repoRoot
  $targetContract = $contract.$environment
  $manifest = [ordered]@{
    schema_version = 1
    kind = 'release-gate'
    channel = $Channel
    environment = $environment
    status = $status
    project_ref = $ProjectRef
    git_sha = $ExpectedGitSha
    migration_head = $ExpectedMigrationHead
    release_enabled = [bool]$targetContract.release_enabled
    production_authorization_used = $productionAuthorizationUsed
    started_at_utc = $startedAt.ToString('o')
    completed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    failure = Protect-DeployText -Text $failure
  }
  Write-DeployJson -Value $manifest -Path (Join-Path $evidenceDirectory 'release-gate-manifest.json')
  Write-Host "Evidence: $evidenceDirectory"
}
