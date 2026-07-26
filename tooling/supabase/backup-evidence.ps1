[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('production')][string]$Environment,
  [Parameter(Mandatory)][string]$ProjectRef,
  [Parameter(Mandatory)][string]$ExpectedGitSha,
  [Parameter(Mandatory)][string]$ExpectedMigrationHead,
  [string]$OutputPath
)

# Production apply backup kanıtını insan elinden alır: Supabase Management
# API'nin gerçek backup/PITR durumunu okur, kanıt üretilemiyorsa fail-closed
# durur.  Hiçbir mutasyon yapmaz, token'ı asla yazdırmaz.
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DeployGuard.psm1') -Force

if ($ProjectRef -notmatch '^[a-z]{20}$') {
  throw 'Backup evidence requires a valid Supabase project ref.'
}
if ([string]::IsNullOrWhiteSpace($env:SUPABASE_ACCESS_TOKEN)) {
  throw 'Backup evidence requires SUPABASE_ACCESS_TOKEN from the protected environment secret store.'
}

$response = Invoke-RestMethod -Method Get `
  -Uri "https://api.supabase.com/v1/projects/$ProjectRef/database/backups" `
  -Headers @{ Authorization = "Bearer $($env:SUPABASE_ACCESS_TOKEN)" } `
  -ErrorAction Stop

$evidence = New-ProductionBackupEvidence -BackupApiResponse $response -ProjectRef $ProjectRef `
  -ExpectedGitSha $ExpectedGitSha -ExpectedMigrationHead $ExpectedMigrationHead

$json = ($evidence | ConvertTo-Json -Depth 6 -Compress)
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  [IO.File]::WriteAllText($OutputPath, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

Write-Host "Backup evidence resolved: $($evidence.backup_id) captured_at=$($evidence.captured_at_utc)"
return $json
