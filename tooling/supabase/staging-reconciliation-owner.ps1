[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('prepare', 'apply')][string]$Action,
  [Parameter(Mandatory)][string]$ExpectedGitSha,
  [string]$ExpectedMigrationHead = '0064',
  [string]$StagingProjectRef = 'rskiuyjabyzelqododpa',
  [string]$ProductionProjectRef = 'jiphfrpzvkpzubbkhrwb',
  [string]$NodePath = 'C:\Users\muhlis2\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$remoteScript = Join-Path $PSScriptRoot 'remote.ps1'
$supabaseUrl = "https://$StagingProjectRef.supabase.co"

Write-Host ''
Write-Host 'WP-229 reconciliation acceptance (staging only)'
Write-Host "  Action: $Action"
Write-Host "  Staging: $StagingProjectRef"
Write-Host "  Production: $ProductionProjectRef (LOCKED)"
$expectedConfirmation = if ($Action -eq 'prepare') { 'PREPARE STAGING RECONCILIATION' } else { 'APPLY STAGING RECONCILIATION' }
$confirmation = Read-Host "Continue by typing $expectedConfirmation"
if ($confirmation -cne $expectedConfirmation) {
  throw 'Exact staging reconciliation confirmation was not provided.'
}

$securePassword = Read-Host 'Staging DB password' -AsSecureString
$passwordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
  $env:SUPABASE_DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
}

try {
  & $remoteScript `
    -Environment staging `
    -Action "reconcile-$Action" `
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
