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

Assert-Equal (Get-LocalMigrationHead -RepoRoot $repoRoot) '0070' 'local migration head'
Assert-Equal ((Get-DeployContract -RepoRoot $repoRoot).local_migration_head) '0070' 'contract migration head'
$contract = Get-DeployContract -RepoRoot $repoRoot
Assert-Equal $contract.staging.migration_head '0070' 'staging migration head'
Assert-Equal ([bool]$contract.staging.deploy_enabled) $true 'staging deploy enabled'
Assert-Equal ([bool]$contract.staging.release_enabled) $true 'staging release enabled'
Assert-Equal $contract.production.migration_head '0065' 'production head 0065: applied manually, chain repair is WP-232'
Assert-Equal ([bool]$contract.production.deploy_enabled) $false 'production deploy defaults to HOLD'
Assert-Equal ([bool]$contract.production.release_enabled) $false 'production release defaults to HOLD'

$databaseWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\database-gates.yml') -Raw -Encoding UTF8
$releaseWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\release.yml') -Raw -Encoding UTF8
$windowsWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\windows-release.yml') -Raw -Encoding UTF8
if ($databaseWorkflow -match '(?im)flutter|beta-build\.ps1|KEYSTORE_BASE64') {
  throw 'Database Gates must not build Flutter/APK candidates.'
}
if ($releaseWorkflow -notmatch 'release-status-manifest' -or $releaseWorkflow -notmatch 'needs: \[preflight, android, windows\]') {
  throw 'Release orchestration must expose a single aggregate status manifest and wait for both platforms.'
}
if ($windowsWorkflow -match 'action-gh-release' -or $windowsWorkflow -notmatch 'workflow_call:') {
  throw 'Windows workflow must be reusable and cannot finalize a GitHub Release independently.'
}
$passed += 3

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

$pushDispatchPostCheckSql = Get-StagingPushDispatchPostCheckSql
Assert-StagingPushDispatchPostCheck -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushDispatchPostCheckSql
$passed++
foreach ($requiredMarker in @('pg_net', "n.nspname = 'net'", "p.proname = 'http_post'")) {
  if ($pushDispatchPostCheckSql -notmatch [regex]::Escape($requiredMarker)) {
    throw "Push dispatch post-check is missing: $requiredMarker"
  }
}
$passed++
Assert-Throws -Name 'push dispatch post-check production target denied' -Script {
  Assert-StagingPushDispatchPostCheck -Environment production -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushDispatchPostCheckSql
}
Assert-Throws -Name 'arbitrary push dispatch post-check SQL denied' -Script {
  Assert-StagingPushDispatchPostCheck -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql 'select 1;'
}
Assert-Throws -Name 'production ref push dispatch post-check masquerade denied' -Script {
  Assert-StagingPushDispatchPostCheck -Environment staging -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushDispatchPostCheckSql
}

$pushRuntimeDiagnosticSql = Get-StagingPushRuntimeDiagnosticSql
Assert-StagingPushRuntimeDiagnostic -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushRuntimeDiagnosticSql
$passed++
foreach ($requiredMarker in @(
  'begin transaction read only',
  'cron.job_run_details',
  'pg_net_catalog',
  'pg_extension',
  'pg_proc',
  'push_dispatch_runtime_config',
  'get_push_dispatch_queue_health',
  'notification_deliveries',
  'available_now',
  'device_disabled',
  'preference_enabled',
  'rollback'
)) {
  if ($pushRuntimeDiagnosticSql -notmatch [regex]::Escape($requiredMarker)) {
    throw "Push runtime diagnostic is missing: $requiredMarker"
  }
}
$passed++
foreach ($forbiddenOutput in @('fcm_token', 'payload', 'provider_message_id', 'recipient_id', 'installation_id')) {
  if ($pushRuntimeDiagnosticSql -match "\b$forbiddenOutput\b") {
    throw "Push runtime diagnostic exposes a sensitive field: $forbiddenOutput"
  }
}
$passed++
Assert-Throws -Name 'push runtime diagnostic production target denied' -Script {
  Assert-StagingPushRuntimeDiagnostic -Environment production -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushRuntimeDiagnosticSql
}
Assert-Throws -Name 'push runtime diagnostic arbitrary SQL denied' -Script {
  Assert-StagingPushRuntimeDiagnostic -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql 'select * from public.push_dispatch_runtime_config;'
}
Assert-Throws -Name 'push runtime diagnostic production ref masquerade denied' -Script {
  Assert-StagingPushRuntimeDiagnostic -Environment staging -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $pushRuntimeDiagnosticSql
}

$pushDiagnosticWorkflowPath = Join-Path $repoRoot '.github\workflows\staging-push-diagnostics.yml'
$pushDiagnosticWorkflow = Get-Content -LiteralPath $pushDiagnosticWorkflowPath -Raw -Encoding UTF8
if ($pushDiagnosticWorkflow -notmatch '(?m)^\s*workflow_dispatch:\s*$' -or
    $pushDiagnosticWorkflow -match '(?m)^\s*push:\s*$' -or
    $pushDiagnosticWorkflow -notmatch 'Action\s*=\s*''inspect-push-runtime''' -or
    $pushDiagnosticWorkflow -match 'staging-apply|production-apply|Action\s*=\s*''apply''|db push') {
  throw 'Staging push diagnostics workflow must remain manual and read-only.'
}
$passed++

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
