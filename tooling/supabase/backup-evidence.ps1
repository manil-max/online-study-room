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

# Kanıt üretilemezse neden fail-closed durduğumuz teşhis edilebilir olmalı:
# yalnız sır içermeyen alanlar özetlenir.
try {
  $evidence = New-ProductionBackupEvidence -BackupApiResponse $response -ProjectRef $ProjectRef `
    -ExpectedGitSha $ExpectedGitSha -ExpectedMigrationHead $ExpectedMigrationHead
} catch {
  $summary = [ordered]@{
    pitr_enabled = [bool]$response.pitr_enabled
    walg_enabled = [bool]$response.walg_enabled
    region = [string]$response.region
    backup_count = @($response.backups).Count
    backups = @(@($response.backups) | ForEach-Object {
      [ordered]@{ status = [string]$_.status; inserted_at = [string]$_.inserted_at; is_physical = [bool]$_.is_physical_backup }
    })
    physical_backup_data = $response.physical_backup_data
  }
  Write-Host "Backup API summary: $($summary | ConvertTo-Json -Depth 6 -Compress)"
  throw
}

$json = ($evidence | ConvertTo-Json -Depth 6 -Compress)
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  [IO.File]::WriteAllText($OutputPath, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

Write-Host "Backup evidence resolved: $($evidence.backup_id) captured_at=$($evidence.captured_at_utc)"
return $json
