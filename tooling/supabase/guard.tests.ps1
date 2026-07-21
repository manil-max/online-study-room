$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DeployGuard.psm1') -Force

$passed = 0
function Assert-Throws {
  param([scriptblock]$Script, [string]$Name)
  try {
    & $Script
    throw "Expected failure did not occur: $Name"
  } catch {
    if ($_.Exception.Message -like 'Expected failure did not occur:*') { throw }
    $script:passed++
  }
}
function Assert-Equal {
  param($Actual, $Expected, [string]$Name)
  if ($Actual -ne $Expected) { throw "$Name expected '$Expected', got '$Actual'" }
  $script:passed++
}

$repoRoot = Get-RepoRoot
$stagingRef = 'aaaaaaaaaaaaaaaaaaaa'
$productionRef = 'bbbbbbbbbbbbbbbbbbbb'

Assert-Equal (Get-LocalMigrationHead -RepoRoot $repoRoot) '0065' 'local migration head'
Assert-Equal ((Get-DeployContract -RepoRoot $repoRoot).local_migration_head) '0065' 'contract migration head'
$contract = Get-DeployContract -RepoRoot $repoRoot
Assert-Equal $contract.staging.migration_head '0065' 'staging migration head'
Assert-Equal ([bool]$contract.staging.deploy_enabled) $true 'staging deploy enabled'
Assert-Equal ([bool]$contract.staging.release_enabled) $true 'staging release enabled'
Assert-Equal $contract.production.migration_head '0065' 'production head matches the released chain'
Assert-Equal ([bool]$contract.production.deploy_enabled) $true 'production deploy opened for v43'
Assert-Equal ([bool]$contract.production.release_enabled) $true 'production release opened for v43'

Assert-TargetContract -Environment staging -ProjectRef $stagingRef -SupabaseUrl "https://$stagingRef.supabase.co" -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -RepoRoot $repoRoot -IgnoreLinkedRef
$passed++

Assert-Throws -Name 'wrong staging ref' -Script {
  Assert-TargetContract -Environment staging -ProjectRef $productionRef -SupabaseUrl "https://$productionRef.supabase.co" -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -RepoRoot $repoRoot -IgnoreLinkedRef
}
Assert-Throws -Name 'URL/ref mismatch' -Script {
  Assert-TargetContract -Environment staging -ProjectRef $stagingRef -SupabaseUrl "https://$productionRef.supabase.co" -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -RepoRoot $repoRoot -IgnoreLinkedRef
}
Assert-Throws -Name 'same staging/production refs' -Script {
  Assert-TargetContract -Environment staging -ProjectRef $stagingRef -SupabaseUrl "https://$stagingRef.supabase.co" -StagingProjectRef $stagingRef -ProductionProjectRef $stagingRef -RepoRoot $repoRoot -IgnoreLinkedRef
}

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "wp228-guard-$([guid]::NewGuid().ToString('N'))"
try {
  $linkedDirectory = Join-Path $fixtureRoot 'supabase\.temp'
  [IO.Directory]::CreateDirectory($linkedDirectory) | Out-Null
  [IO.File]::WriteAllText((Join-Path $linkedDirectory 'project-ref'), $productionRef)
  Assert-Throws -Name 'stale CLI link' -Script {
    Assert-TargetContract -Environment staging -ProjectRef $stagingRef -SupabaseUrl "https://$stagingRef.supabase.co" -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -RepoRoot $fixtureRoot
  }
} finally {
  if ([IO.Directory]::Exists($fixtureRoot)) { [IO.Directory]::Delete($fixtureRoot, $true) }
}

foreach ($arguments in @(
  @('db', 'reset', '--linked'),
  @('db', 'reset', '--db-url', 'postgres://example'),
  @('migration', 'repair', '--status', 'applied'),
  @('db', 'query', 'truncate table public.study_sessions')
)) {
  Assert-Throws -Name "deny $($arguments -join ' ')" -Script { Assert-SafeSupabaseArguments -Arguments $arguments }
}

Assert-SafeSupabaseArguments -Arguments @('db', 'reset')
$passed++
Assert-SafeSupabaseArguments -Arguments @('db', 'push', '--linked', '--dry-run')
$passed++

$inspectSql = Get-StagingPrerequisiteSql -Action inspect
$bootstrapSql = Get-StagingPrerequisiteSql -Action bootstrap
Assert-StagingPrerequisiteAction -Action inspect -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $inspectSql
$passed++
Assert-StagingPrerequisiteAction -Action bootstrap -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $bootstrapSql
$passed++
Assert-Throws -Name 'prerequisite production target denied' -Script {
  Assert-StagingPrerequisiteAction -Action bootstrap -Environment production -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $bootstrapSql
}
Assert-Throws -Name 'arbitrary prerequisite SQL denied' -Script {
  Assert-StagingPrerequisiteAction -Action bootstrap -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql 'create extension if not exists http;'
}
Assert-Throws -Name 'production ref masquerading as staging denied' -Script {
  Assert-StagingPrerequisiteAction -Action bootstrap -Environment staging -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $bootstrapSql
}

$reconciliationPrepareSql = Get-StagingReconciliationSql -Action prepare
$reconciliationPrepareInspectSql = Get-StagingReconciliationSql -Action prepare-inspect
$reconciliationApplySql = Get-StagingReconciliationSql -Action apply
$reconciliationApplyInspectSql = Get-StagingReconciliationSql -Action apply-inspect
Assert-StagingReconciliationAction -Action prepare -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationPrepareSql
$passed++
Assert-StagingReconciliationAction -Action prepare-inspect -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationPrepareInspectSql
$passed++
Assert-StagingReconciliationAction -Action apply -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationApplySql
$passed++
Assert-StagingReconciliationAction -Action apply-inspect -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationApplyInspectSql
$passed++
Assert-Throws -Name 'reconciliation production target denied' -Script {
  Assert-StagingReconciliationAction -Action apply -Environment production -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationApplySql
}
Assert-Throws -Name 'arbitrary reconciliation SQL denied' -Script {
  Assert-StagingReconciliationAction -Action prepare -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql 'select public.prepare_equal_source_reconciliation(500, null);'
}
Assert-Throws -Name 'production ref reconciliation masquerade denied' -Script {
  Assert-StagingReconciliationAction -Action prepare -Environment staging -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $reconciliationPrepareSql
}

$sha = '0123456789abcdef0123456789abcdef01234567'
$confirmation = "PRODUCTION GO:$sha`:0063`:$productionRef"
$backup = '{"backup_id":"backup-123","captured_at_utc":"2026-07-20T10:00:00Z","restore_strategy":"point-in-time recovery verified","session_baseline_evidence":"artifact/session.json","xp_reconciliation_evidence":"artifact/xp.json","post_check_plan":"artifact/post-check.json"}'
Assert-Throws -Name 'production environment approval required' -Script {
  Assert-ProductionApproval -ExpectedGitSha $sha -ExpectedMigrationHead '0063' -ProjectRef $productionRef -BackupEvidence $backup -Confirmation $confirmation -GitHubActions 'false' -ApprovalEnvironment 'production'
}
Assert-Throws -Name 'production backup required' -Script {
  Assert-ProductionApproval -ExpectedGitSha $sha -ExpectedMigrationHead '0063' -ProjectRef $productionRef -BackupEvidence 'skip' -Confirmation $confirmation -GitHubActions 'true' -ApprovalEnvironment 'production'
}
Assert-Throws -Name 'exact production GO required' -Script {
  Assert-ProductionApproval -ExpectedGitSha $sha -ExpectedMigrationHead '0063' -ProjectRef $productionRef -BackupEvidence $backup -Confirmation 'PRODUCTION GO' -GitHubActions 'true' -ApprovalEnvironment 'production'
}
Assert-ProductionApproval -ExpectedGitSha $sha -ExpectedMigrationHead '0063' -ProjectRef $productionRef -BackupEvidence $backup -Confirmation $confirmation -GitHubActions 'true' -ApprovalEnvironment 'production'
$passed++

$secret = 'sb_secret_should_never_leak'
$redacted = Protect-DeployText -Text "token=$secret Bearer access-token postgres://user:password@host/db eyJaaa.bbb.ccc`n`"JWT_SECRET`": `"local-jwt`"`n`"S3_PROTOCOL_ACCESS_KEY_SECRET`": `"local-s3`"" -SensitiveValues @($secret)
if ($redacted.Contains($secret) -or $redacted.Contains('access-token') -or $redacted.Contains('password') -or $redacted.Contains('eyJaaa') -or $redacted.Contains('local-jwt') -or $redacted.Contains('local-s3')) {
  throw 'Secret redaction test failed.'
}
$passed++

Write-Host "Deploy guard tests: $passed passed."
