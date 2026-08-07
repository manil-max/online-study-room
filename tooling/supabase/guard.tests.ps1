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

$contract = Get-DeployContract -RepoRoot $repoRoot
# 🔴 Yerel head ARTIK burada sabit sayiyla pinli DEGIL: tek kaynak
# deploy-contract.json. Uc turda ust uste CI tam bu satirdan kirmizi dustu -
# migration ekleyen WP kontrati guncelliyor, bu dosyayi unutuyordu.
# Burada yalniz dizin ile kontratin birbirini tuttugu dogrulanir.
# Uzak ortam head'leri (staging/production) BILEREK sabit kalir: onlar
# gercekten uygulanmis semayi koruyan kapilardir, otomatik takip etmemeli.
Assert-Equal (Get-LocalMigrationHead -RepoRoot $repoRoot) $contract.local_migration_head 'yerel head = kontrat head'
# v56 0100 üç ortamda uygulandı ve stable yayınlandı. Geçici apply/release GO'su
# tüketildi; staging ve production kapıları politika gereği yeniden HOLD'dadır.
# 🔴 Head ve kapı durumu ÜÇ yerde pinli: kontrat, bu dosya ve
# release-preflight.tests.ps1. Biri unutulursa CI tam buradan kırmızı düşer.
# 2026-08-01: v58 adayi 0117-0119'u tasir. Yerel baseline 48 dosya / 678
# pgTAP ile gecti; sahip zincirin tamamlanip stable v58 yayimlanmasini istedi.
# Staging ve production deploy flag'leri bu aday icin tek seferlik aciktir.
# Remote gercek head apply oncesi 0116 olsa da kontrat hedefi 0119'a pinler;
# protected workflow list/dry-run/post-check ile farki dogrular. release_enabled
# false kalir: stable exact SHA/head/project-ref confirmation ve kanit ister.
# production release_enabled v58 stable icin tek seferlik acildi (0117-0119
# production apply post-check 0119 sonrasi). Zincir sonunda tum flag'ler
# yeniden false kilitlenmelidir.
# 2026-08-07: sahip "cihaz testine gönder" tetikleyicisiyle WP-490/491/492/501
# zincirini (0120-0121) staging+production'a taşımak için kapsamlı, tek turluk
# apply yetkisi verdi. Kontrat hedefi 0121'e, deploy_enabled true'ya çekildi;
# release_enabled BİLEREK false kalır (stable release ayrı, tek seferlik
# confirmation string'iyle geçer, bkz. release-gate.ps1). Apply turu bitince bu
# iki pin (deploy_enabled) yeniden false'a re-lock edilir, migration_head 0121
# olarak kalıcılaşır.
Assert-Equal $contract.staging.migration_head '0121' 'v59 apply turu staging hedef head 0121'
Assert-Equal ([bool]$contract.staging.deploy_enabled) $true 'v59 apply turu staging gecici acik'
Assert-Equal ([bool]$contract.staging.release_enabled) $false 'staging release istenmedi'
Assert-Equal $contract.production.migration_head '0121' 'v59 apply turu production hedef head 0121'
Assert-Equal ([bool]$contract.production.deploy_enabled) $true 'v59 apply turu production gecici acik'
Assert-Equal ([bool]$contract.production.release_enabled) $false 'release_enabled acik degil, confirmation string ile geciliyor'

$databaseWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\database-gates.yml') -Raw -Encoding UTF8
$releaseWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\release.yml') -Raw -Encoding UTF8
$windowsWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\windows-release.yml') -Raw -Encoding UTF8
if ($databaseWorkflow -match '(?im)flutter|beta-build\.ps1|KEYSTORE_BASE64') {
  throw 'Database Gates must not build Flutter/APK candidates.'
}
if ($releaseWorkflow -notmatch 'release-status-manifest' -or
    $releaseWorkflow -notmatch 'finalize_android:' -or
    $releaseWorkflow -notmatch 'needs: \[preflight, android\]' -or
    $releaseWorkflow -notmatch 'finalize_complete:' -or
    $releaseWorkflow -notmatch 'needs: \[preflight, android, windows\]') {
  throw 'Release orchestration must publish Android-first channels and keep the complete two-platform attachment path.'
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

$v3CompatibilitySql = Get-V3LegacyCompatibilitySql
Assert-V3LegacyCompatibilityInspection -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $v3CompatibilitySql
$passed++
Assert-V3LegacyCompatibilityInspection -Environment production -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $v3CompatibilitySql
$passed++
foreach ($requiredMarker in @('select json_build_object', 'live_study_runs', 'open_run_counts', 'active_run_indexes', 'status_constraints')) {
  if ($v3CompatibilitySql -notmatch [regex]::Escape($requiredMarker)) {
    throw "V3 compatibility inspection is missing: $requiredMarker"
  }
}
$passed++
Assert-Throws -Name 'v3 compatibility arbitrary SQL denied' -Script {
  Assert-V3LegacyCompatibilityInspection -Environment staging -ProjectRef $stagingRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql 'select * from public.live_study_runs;'
}
Assert-Throws -Name 'v3 compatibility production ref masquerade denied' -Script {
  Assert-V3LegacyCompatibilityInspection -Environment staging -ProjectRef $productionRef -StagingProjectRef $stagingRef -ProductionProjectRef $productionRef -Sql $v3CompatibilitySql
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

# Backup kanıtı artık API yanıtından türetilir; kanıt yoksa apply açılmaz.
$now = [DateTimeOffset]::Parse('2026-07-27T00:00:00Z')
Assert-Throws -Name 'backup evidence requires a real recovery point' -Script {
  New-ProductionBackupEvidence -BackupApiResponse ([pscustomobject]@{ pitr_enabled = $false; backups = @() }) `
    -ProjectRef $productionRef -ExpectedGitSha $sha -ExpectedMigrationHead '0085' -NowUtc $now
}
Assert-Throws -Name 'stale backup rejected' -Script {
  New-ProductionBackupEvidence -BackupApiResponse ([pscustomobject]@{ pitr_enabled = $false; backups = @(
    [pscustomobject]@{ status = 'COMPLETED'; inserted_at = '2026-07-20T00:00:00Z' }) }) `
    -ProjectRef $productionRef -ExpectedGitSha $sha -ExpectedMigrationHead '0085' -NowUtc $now
}
Assert-Throws -Name 'incomplete backup rejected' -Script {
  New-ProductionBackupEvidence -BackupApiResponse ([pscustomobject]@{ pitr_enabled = $false; backups = @(
    [pscustomobject]@{ status = 'PENDING'; inserted_at = '2026-07-26T22:00:00Z' }) }) `
    -ProjectRef $productionRef -ExpectedGitSha $sha -ExpectedMigrationHead '0085' -NowUtc $now
}
# Baseline onarımı: yalnız 0001-0070'i applied işaretler, şemaya DDL göndermez.
$repairArguments = Get-ProductionBaselineRepairArguments -BaselineHead '0070' -RepoRoot $repoRoot
Assert-Equal $repairArguments[0] 'migration' 'baseline repair komutu'
Assert-Equal ($repairArguments -contains '0070') $true 'baseline 0070 dahil'
Assert-Equal ($repairArguments -contains '0071') $false 'baseline 0071 haric'
Assert-Equal ($repairArguments -contains '0085') $false 'baseline 0085 haric'
Assert-Throws -Name 'baseline repair blocked outside production' -Script {
  Assert-ProductionBaselineRepair -Environment staging -ProjectRef $stagingRef -ProductionProjectRef $productionRef `
    -Arguments $repairArguments -BaselineHead '0070' -GitHubActions 'true' -ApprovalEnvironment 'production'
}
Assert-Throws -Name 'baseline repair blocked outside CI' -Script {
  Assert-ProductionBaselineRepair -Environment production -ProjectRef $productionRef -ProductionProjectRef $productionRef `
    -Arguments $repairArguments -BaselineHead '0070' -GitHubActions 'false' -ApprovalEnvironment 'production'
}
Assert-Throws -Name 'baseline repair rejects newer versions' -Script {
  Assert-ProductionBaselineRepair -Environment production -ProjectRef $productionRef -ProductionProjectRef $productionRef `
    -Arguments (@('migration', 'repair', '--linked', '--status', 'applied', '0085')) -BaselineHead '0070' `
    -GitHubActions 'true' -ApprovalEnvironment 'production'
}
Assert-Throws -Name 'baseline repair rejects reverted status' -Script {
  Assert-ProductionBaselineRepair -Environment production -ProjectRef $productionRef -ProductionProjectRef $productionRef `
    -Arguments (@('migration', 'repair', '--linked', '--status', 'reverted', '0070')) -BaselineHead '0070' `
    -GitHubActions 'true' -ApprovalEnvironment 'production'
}
Assert-ProductionBaselineRepair -Environment production -ProjectRef $productionRef -ProductionProjectRef $productionRef `
  -Arguments $repairArguments -BaselineHead '0070' -GitHubActions 'true' -ApprovalEnvironment 'production'
$passed++
# `migration repair` yalnız bu dar yolda serbesttir.
Assert-Throws -Name 'migration repair denied by default' -Script {
  Assert-SafeSupabaseArguments -Arguments $repairArguments
}
Assert-SafeSupabaseArguments -Arguments $repairArguments -AllowBaselineRepair
$passed++

Assert-Equal ([string]$contract.production.backup_requirement) 'waived' 'sahip kararı: production yedeksiz apply'
Assert-Throws -Name 'incomplete waiver rejected' -Script {
  New-ProductionBackupEvidence -BackupApiResponse $null -ProjectRef $productionRef -ExpectedGitSha $sha `
    -ExpectedMigrationHead '0085' -BackupWaiver ([pscustomobject]@{ decided_by = 'owner'; reason = '' })
}
$waived = New-ProductionBackupEvidence -BackupApiResponse $null -ProjectRef $productionRef -ExpectedGitSha $sha `
  -ExpectedMigrationHead '0085' -BackupWaiver $contract.production.backup_waiver
if ($waived.restore_strategy -notlike 'NONE - owner waived*') { throw 'Waived evidence must state that no rollback exists.' }
$passed++
$freshBackup = New-ProductionBackupEvidence -BackupApiResponse ([pscustomobject]@{ pitr_enabled = $false; backups = @(
  [pscustomobject]@{ status = 'COMPLETED'; inserted_at = '2026-07-26T20:00:00Z'; id = 'bkp-77' }) }) `
  -ProjectRef $productionRef -ExpectedGitSha $sha -ExpectedMigrationHead '0085' -NowUtc $now
Assert-Equal $freshBackup.backup_id "daily:$productionRef`:bkp-77" 'fresh daily backup id'
# Türetilen kanıt, production onay kapısını olduğu gibi geçmelidir.
$derivedConfirmation = "PRODUCTION GO:$sha`:0085`:$productionRef"
Assert-ProductionApproval -ExpectedGitSha $sha -ExpectedMigrationHead '0085' -ProjectRef $productionRef `
  -BackupEvidence ($freshBackup | ConvertTo-Json -Depth 6 -Compress) -Confirmation $derivedConfirmation `
  -GitHubActions 'true' -ApprovalEnvironment 'production'
$passed++
if ($databaseWorkflow -notmatch 'backup-evidence\.ps1' -or $databaseWorkflow -notmatch 'RESOLVED_BACKUP_EVIDENCE') {
  throw 'Database Gates must resolve production backup evidence from Supabase.'
}
$passed++

$secret = 'sb_secret_should_never_leak'
$redacted = Protect-DeployText -Text "token=$secret Bearer access-token postgres://user:password@host/db eyJaaa.bbb.ccc`n`"JWT_SECRET`": `"local-jwt`"`n`"S3_PROTOCOL_ACCESS_KEY_SECRET`": `"local-s3`"" -SensitiveValues @($secret)
if ($redacted.Contains($secret) -or $redacted.Contains('access-token') -or $redacted.Contains('password') -or $redacted.Contains('eyJaaa') -or $redacted.Contains('local-jwt') -or $redacted.Contains('local-s3')) {
  throw 'Secret redaction test failed.'
}
$passed++

Write-Host "Deploy guard tests: $passed passed."
