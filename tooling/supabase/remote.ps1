[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('staging', 'production')][string]$Environment,
  [Parameter(Mandatory)][ValidateSet('inspect-prerequisites', 'inspect-push-runtime', 'bootstrap-prerequisites', 'reconcile-prepare', 'reconcile-apply', 'preflight', 'dry-run', 'apply', 'manual-push-0066-0070')][string]$Action,
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

# Production never had Supabase CLI migration history: historic migrations were
# applied through SQL Editor.  This deliberately narrow path applies only the
# five reviewed push migrations, without repairing or inventing that history.
$manualPushMigrations = [ordered]@{
  '0066_push_notification_delivery.sql' = '97CA5B7297856F46E348433B1A2FFAB810A5C008C544ADC060B4A47F84797EBA'
  '0067_push_dispatch_runtime_config.sql' = '4E5C7107552D283226BC848FE0B9B781848FFC5094EBC3883E89DF2C713DAC4A'
  '0068_revoke_push_dispatch_config_rpc.sql' = '5ED4DFA982AD27B87DB16AFB48679DF270C9D98433468E2A9CCDC62CF903A03F'
  '0069_push_dispatch_retry_health.sql' = 'BDA5C935EEBA42A1A6A727DC32A36994DBB39D904641D7D61B5263BF8568FF5C'
  '0070_require_pg_net_for_push_dispatch.sql' = 'E8F5288468928AD4D59D429A502C6B11F952D17551D70B2DD81DAFA077EFFFE9'
}

function Invoke-ManualPushMigration {
  param([Parameter(Mandatory)][string]$FileName)

  if (-not $manualPushMigrations.Contains($FileName)) {
    throw "Manual production migration is not allowlisted: $FileName"
  }
  $path = Join-Path $repoRoot "supabase/migrations/$FileName"
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Allowlisted manual production migration is missing: $FileName"
  }
  $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToUpperInvariant()
  if ($actualHash -cne $manualPushMigrations[$FileName]) {
    throw "Manual production migration hash mismatch: $FileName"
  }

  $sql = "begin;`n" + (Get-Content -LiteralPath $path -Raw -Encoding UTF8) + "`ncommit;"
  $steps.Add("manual-$FileName")
  $nodeArguments = @($cliEntry, 'db', 'query', '--linked', $sql, '--workdir', $repoRoot)
  Invoke-EvidenceCommand -Executable $NodePath -Arguments $nodeArguments -EvidenceDirectory $evidenceDirectory -Label "manual-$FileName" -SensitiveValues $sensitiveValues | Out-Null
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
  if ($Action -in @('apply', 'manual-push-0066-0070', 'bootstrap-prerequisites', 'reconcile-prepare', 'reconcile-apply') -and -not [bool]$targetContract.deploy_enabled) {
    throw "Deploy HOLD: $($targetContract.hold_reason)"
  }

  if ($Action -in @('inspect-prerequisites', 'inspect-push-runtime', 'bootstrap-prerequisites', 'reconcile-prepare', 'reconcile-apply') -and $Environment -ne 'staging') {
    throw 'Prerequisite and reconciliation actions are staging-only.'
  }

  if ($env:GITHUB_ACTIONS -eq 'true' -and [string]::IsNullOrWhiteSpace($env:SUPABASE_ACCESS_TOKEN)) {
    throw 'CI requires SUPABASE_ACCESS_TOKEN from the protected environment secret store.'
  }
  if ([string]::IsNullOrWhiteSpace($env:SUPABASE_DB_PASSWORD)) {
    throw 'SUPABASE_DB_PASSWORD must come from the environment secret store.'
  }

  if ($Environment -eq 'production' -and $Action -in @('apply', 'manual-push-0066-0070')) {
    Assert-ProductionApproval -ExpectedGitSha $ExpectedGitSha -ExpectedMigrationHead $ExpectedMigrationHead -ProjectRef $ProjectRef -BackupEvidence $BackupEvidence -Confirmation $ConfirmProductionGo -GitHubActions $env:GITHUB_ACTIONS -ApprovalEnvironment $env:DEPLOY_APPROVAL_ENVIRONMENT
  }

  Invoke-RemoteSupabase -Arguments @('link', '--project-ref', $ProjectRef) -Label '01-explicit-link'
  $linkedRefPath = Join-Path $repoRoot 'supabase\.temp\project-ref'
  if (-not (Test-Path -LiteralPath $linkedRefPath) -or (Get-Content -LiteralPath $linkedRefPath -Raw -Encoding UTF8).Trim() -ne $ProjectRef) {
    throw 'Supabase CLI link post-check failed.'
  }

  if ($Action -eq 'manual-push-0066-0070') {
    if ($Environment -ne 'production') {
      throw 'Manual push migration path is production-only.'
    }
    foreach ($fileName in $manualPushMigrations.Keys) {
      Invoke-ManualPushMigration -FileName $fileName
    }
    $postCheckSql = @'
do $post_check$
begin
  if to_regclass('public.push_devices') is null
     or to_regclass('public.notification_outbox') is null
     or to_regclass('public.notification_deliveries') is null
     or to_regclass('public.push_dispatch_runtime_config') is null then
    raise exception 'manual_push_post_check_missing_push_relation';
  end if;
  if not exists (select 1 from pg_extension where extname = 'pg_cron')
     or not exists (select 1 from pg_extension where extname = 'pg_net')
     or not exists (select 1 from cron.job where jobname = 'push-dispatch-retry-worker') then
    raise exception 'manual_push_post_check_missing_transport_or_worker';
  end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'get_push_dispatch_queue_health'
  ) then
    raise exception 'manual_push_post_check_missing_health_rpc';
  end if;
end
$post_check$;
'@
    Invoke-RemoteSupabase -Arguments @('db', 'query', '--linked', $postCheckSql) -Label 'manual-push-post-check'
  } elseif ($Action -eq 'inspect-push-runtime') {
    Invoke-RemoteSupabase -Arguments @('migration', 'list', '--linked') -Label '02-migration-list'
    $diagnosticSql = Get-StagingPushRuntimeDiagnosticSql
    Assert-StagingPushRuntimeDiagnostic -Environment $Environment -ProjectRef $ProjectRef -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef -Sql $diagnosticSql
    Invoke-RemoteSupabase -Arguments @('db', 'query', '--linked', $diagnosticSql) -Label '03-push-runtime-diagnostic'
  } elseif ($Action -in @('inspect-prerequisites', 'bootstrap-prerequisites')) {
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
