[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('staging', 'production')][string]$Environment,
  [Parameter(Mandatory)][ValidateSet('inspect-prerequisites', 'bootstrap-prerequisites', 'reconcile-prepare', 'reconcile-apply', 'preflight', 'dry-run', 'apply')][string]$Action,
  [Parameter(Mandatory)][string]$ProjectRef,
  [Parameter(Mandatory)][string]$SupabaseUrl,
  [Parameter(Mandatory)][string]$StagingProjectRef,
  [Parameter(Mandatory)][string]$ProductionProjectRef,
  [Parameter(Mandatory)][string]$ExpectedGitSha,
  [Parameter(Mandatory)][string]$ExpectedMigrationHead,
  [string]$BackupEvidence,
  [string]$ConfirmProductionGo,
  [string]$NodePath,
  [string]$EvidenceRoot
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DeployGuard.psm1') -Force

$repoRoot = Get-RepoRoot
$cliEntry = Join-Path $repoRoot 'node_modules\supabase\dist\supabase.js'
$startedAt = (Get-Date).ToUniversalTime()
$evidenceDirectory = New-EvidenceDirectory -Kind "$Environment-$Action" -EvidenceRoot $EvidenceRoot -RepoRoot $repoRoot
$steps = [Collections.Generic.List[string]]::new()
$status = 'failed'
$failure = $null

$sensitiveValues = @(
  $env:SUPABASE_ACCESS_TOKEN,
  $env:SUPABASE_DB_PASSWORD,
  $env:STAGING_SUPABASE_ANON_KEY,
  $env:PRODUCTION_SUPABASE_ANON_KEY
)

function Invoke-RemoteSupabase {
  param(
    [Parameter(Mandatory)][string[]]$Arguments,
    [Parameter(Mandatory)][string]$Label
  )

  Assert-SafeSupabaseArguments -Arguments $Arguments
  $steps.Add($Label)
  $nodeArguments = @($cliEntry) + $Arguments + @('--workdir', $repoRoot)
  Invoke-EvidenceCommand -Executable $NodePath -Arguments $nodeArguments -EvidenceDirectory $evidenceDirectory -Label $Label -SensitiveValues $sensitiveValues | Out-Null
}

function Write-RemoteManifest {
  $contract = Get-DeployContract -RepoRoot $repoRoot
  $targetContract = $contract.$Environment
  $logs = @()
  foreach ($log in @(Get-ChildItem -LiteralPath $evidenceDirectory -Filter '*.log' -File -ErrorAction SilentlyContinue)) {
    $logs += [ordered]@{
      name = $log.Name
      sha256 = (Get-FileHash -LiteralPath $log.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
  }
  $manifest = [ordered]@{
    schema_version = 1
    kind = 'remote-supabase'
    environment = $Environment
    action = $Action
    status = $status
    project_ref = $ProjectRef
    git_sha = $ExpectedGitSha
    migration_head = $ExpectedMigrationHead
    contract_migration_head = $targetContract.migration_head
    deploy_enabled = [bool]$targetContract.deploy_enabled
    supabase_cli_version = '2.109.1'
    started_at_utc = $startedAt.ToString('o')
    completed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    steps = @($steps)
    evidence_files = $logs
    backup_evidence_recorded = -not [string]::IsNullOrWhiteSpace($BackupEvidence)
    failure = Protect-DeployText -Text $failure -SensitiveValues $sensitiveValues
  }
  Write-DeployJson -Value $manifest -Path (Join-Path $evidenceDirectory 'deploy-manifest.json')
  Write-Host "Evidence: $evidenceDirectory"
}

Push-Location $repoRoot
try {
  Assert-TargetContract -Environment $Environment -ProjectRef $ProjectRef -SupabaseUrl $SupabaseUrl -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef -RepoRoot $repoRoot
  Assert-ExactReleaseIdentity -ExpectedGitSha $ExpectedGitSha -ExpectedMigrationHead $ExpectedMigrationHead -RepoRoot $repoRoot

  if (-not (Test-Path -LiteralPath $cliEntry)) {
    throw 'Pinned Supabase CLI is missing. Run pnpm install --frozen-lockfile.'
  }
  if ([string]::IsNullOrWhiteSpace($NodePath)) {
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCommand) { $NodePath = $nodeCommand.Source }
  }
  if ([string]::IsNullOrWhiteSpace($NodePath) -or -not (Test-Path -LiteralPath $NodePath)) {
    throw 'Node.js was not found. Pass -NodePath with an absolute executable path.'
  }

  $contract = Get-DeployContract -RepoRoot $repoRoot
  $targetContract = $contract.$Environment
  if ($ExpectedMigrationHead -ne $targetContract.migration_head) {
    throw "Deploy contract rejects migration head $ExpectedMigrationHead for $Environment."
  }
  if ($Action -in @('apply', 'bootstrap-prerequisites', 'reconcile-prepare', 'reconcile-apply') -and -not [bool]$targetContract.deploy_enabled) {
    throw "Deploy HOLD: $($targetContract.hold_reason)"
  }

  if ($Action -in @('inspect-prerequisites', 'bootstrap-prerequisites', 'reconcile-prepare', 'reconcile-apply') -and $Environment -ne 'staging') {
    throw 'Prerequisite and reconciliation actions are staging-only.'
  }

  if ($env:GITHUB_ACTIONS -eq 'true' -and [string]::IsNullOrWhiteSpace($env:SUPABASE_ACCESS_TOKEN)) {
    throw 'CI requires SUPABASE_ACCESS_TOKEN from the protected environment secret store.'
  }
  if ([string]::IsNullOrWhiteSpace($env:SUPABASE_DB_PASSWORD)) {
    throw 'SUPABASE_DB_PASSWORD must come from the environment secret store.'
  }

  if ($Environment -eq 'production' -and $Action -eq 'apply') {
    Assert-ProductionApproval -ExpectedGitSha $ExpectedGitSha -ExpectedMigrationHead $ExpectedMigrationHead -ProjectRef $ProjectRef -BackupEvidence $BackupEvidence -Confirmation $ConfirmProductionGo -GitHubActions $env:GITHUB_ACTIONS -ApprovalEnvironment $env:DEPLOY_APPROVAL_ENVIRONMENT
  }

  Invoke-RemoteSupabase -Arguments @('link', '--project-ref', $ProjectRef) -Label '01-explicit-link'
  $linkedRefPath = Join-Path $repoRoot 'supabase\.temp\project-ref'
  if (-not (Test-Path -LiteralPath $linkedRefPath) -or (Get-Content -LiteralPath $linkedRefPath -Raw -Encoding UTF8).Trim() -ne $ProjectRef) {
    throw 'Supabase CLI link post-check failed.'
  }

  if ($Action -in @('inspect-prerequisites', 'bootstrap-prerequisites')) {
    Invoke-RemoteSupabase -Arguments @('migration', 'list', '--linked') -Label '02-migration-list-before'
    $inspectSql = Get-StagingPrerequisiteSql -Action inspect
    Assert-StagingPrerequisiteAction -Action inspect -Environment $Environment -ProjectRef $ProjectRef -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef -Sql $inspectSql
    Invoke-RemoteSupabase -Arguments @('db', 'query', '--linked', $inspectSql) -Label '03-prerequisite-inspect-before'

    if ($Action -eq 'bootstrap-prerequisites') {
      $bootstrapSql = Get-StagingPrerequisiteSql -Action bootstrap
      Assert-StagingPrerequisiteAction -Action bootstrap -Environment $Environment -ProjectRef $ProjectRef -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef -Sql $bootstrapSql
      Invoke-RemoteSupabase -Arguments @('db', 'query', '--linked', $bootstrapSql) -Label '04-pg-cron-bootstrap'
      Invoke-RemoteSupabase -Arguments @('db', 'query', '--linked', $inspectSql) -Label '05-prerequisite-inspect-after'
    }
  } elseif ($Action -in @('reconcile-prepare', 'reconcile-apply')) {
    Invoke-RemoteSupabase -Arguments @('migration', 'list', '--linked') -Label '02-migration-list-before'
    $reconciliationAction = if ($Action -eq 'reconcile-prepare') { 'prepare' } else { 'apply' }
    $reconciliationSql = Get-StagingReconciliationSql -Action $reconciliationAction
    Assert-StagingReconciliationAction -Action $reconciliationAction -Environment $Environment -ProjectRef $ProjectRef -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef -Sql $reconciliationSql
    Invoke-RemoteSupabase -Arguments @('db', 'query', '--linked', $reconciliationSql) -Label "03-reconciliation-$reconciliationAction"
    $reconciliationInspectAction = "$reconciliationAction-inspect"
    $reconciliationInspectSql = Get-StagingReconciliationSql -Action $reconciliationInspectAction
    Assert-StagingReconciliationAction -Action $reconciliationInspectAction -Environment $Environment -ProjectRef $ProjectRef -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef -Sql $reconciliationInspectSql
    Invoke-RemoteSupabase -Arguments @('db', 'query', '--linked', $reconciliationInspectSql) -Label "04-reconciliation-$reconciliationAction-summary"
    Invoke-RemoteSupabase -Arguments @('migration', 'list', '--linked') -Label '05-migration-list-after'
  } else {
    Invoke-RemoteSupabase -Arguments @('migration', 'list', '--linked') -Label '02-migration-list-before'
    Invoke-RemoteSupabase -Arguments @('db', 'push', '--linked', '--dry-run') -Label '03-dry-run'

    if ($Action -eq 'apply') {
      Invoke-RemoteSupabase -Arguments @('db', 'push', '--linked', '--yes') -Label '04-push'
      Invoke-RemoteSupabase -Arguments @('migration', 'list', '--linked') -Label '05-migration-list-after'
      if ($Environment -eq 'staging') {
        $pushDispatchPostCheckSql = Get-StagingPushDispatchPostCheckSql
        Assert-StagingPushDispatchPostCheck -Environment $Environment -ProjectRef $ProjectRef -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef -Sql $pushDispatchPostCheckSql
        Invoke-RemoteSupabase -Arguments @('db', 'query', '--linked', $pushDispatchPostCheckSql) -Label '06-staging-push-dispatch-post-check'
      }
    }
  }

  $status = 'success'
} catch {
  $failure = $_.Exception.Message
  throw
} finally {
  Write-RemoteManifest
  Pop-Location
}
