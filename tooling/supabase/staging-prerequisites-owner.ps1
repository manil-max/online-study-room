[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('inspect', 'bootstrap')][string]$Action,
  [Parameter(Mandatory)][string]$ExpectedGitSha,
  [Parameter(Mandatory)][string]$ExpectedMigrationHead,
  [string]$StagingProjectRef = 'rskiuyjabyzelqododpa',
  [string]$ProductionProjectRef = 'jiphfrpzvkpzubbkhrwb',
  [string]$NodePath = 'C:\Users\muhlis2\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$remoteScript = Join-Path $PSScriptRoot 'remote.ps1'
$supabaseUrl = "https://$StagingProjectRef.supabase.co"

if ($Action -eq 'bootstrap') {
  Write-Host ''
  Write-Host 'Yalnız staging pg_cron önkoşulu kurulacak.'
  Write-Host "  Hedef: $StagingProjectRef"
  Write-Host "  Production: $ProductionProjectRef (KAPALI)"
  $confirmation = Read-Host 'Devam etmek için BOOTSTRAP STAGING PG_CRON yazın'
  if ($confirmation -cne 'BOOTSTRAP STAGING PG_CRON') {
    throw 'Exact staging bootstrap confirmation was not provided.'
  }
}

$securePassword = Read-Host 'Staging DB parolası' -AsSecureString
$passwordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
  $env:SUPABASE_DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
}

try {
  $remoteAction = if ($Action -eq 'inspect') { 'inspect-prerequisites' } else { 'bootstrap-prerequisites' }
  & $remoteScript `
    -Environment staging `
    -Action $remoteAction `
    -ProjectRef $StagingProjectRef `
    -SupabaseUrl $supabaseUrl `
    -StagingProjectRef $StagingProjectRef `
    -ProductionProjectRef $ProductionProjectRef `
    -ExpectedGitSha $ExpectedGitSha `
    -ExpectedMigrationHead $ExpectedMigrationHead `
    -NodePath $NodePath
} finally {
  Remove-Item Env:SUPABASE_DB_PASSWORD -ErrorAction SilentlyContinue
}
